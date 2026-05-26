# frozen_string_literal: true

require "hexapdf"
require "json"
require "date"
require "uri"

require_relative "all_text_processor"
require_relative "validator"
require_relative "constants"

module FormStencil
  class Engine
    attr_reader :template_path, :schema, :overrides, :sections, :normalized_path,
      :mapped_fields, :unmapped_fields, :filled_fields, :missing_fields,
      :select_field_options, :new_fields_detected

    def initialize(template_path, schema: {}, overrides: {}, sections: [], normalized_dir: nil)
      @template_path = template_path
      @schema = schema
      @overrides = overrides
      @sections = sections

      dir = normalized_dir || File.dirname(template_path)
      base = File.basename(template_path, ".*")
      # Avoid double suffixes like "_normalized_normalized.pdf" when the
      # template already contains the normalized marker.
      normalized_base = base.sub(/_normalized\z/, "")
      Dir.mkdir(dir) unless Dir.exist?(dir)
      @normalized_path = File.join(dir, "#{normalized_base}_normalized.pdf")

      @mapped_fields = {}
      @unmapped_fields = []
      @filled_fields = {}
      @missing_fields = []
      @select_field_options = {}
      @new_fields_detected = []
    end

    def source_doc
      @source_doc ||= HexaPDF::Document.open(@template_path)
    end

    def source_form
      @source_form ||= source_doc.acro_form(create: false)
    end

    def raw_fields
      return [] unless source_form
      extracted = []
      source_form.each_field do |field|
        next unless field.is_a?(HexaPDF::Type::AcroForm::Field)
        type = if field.is_a?(HexaPDF::Type::AcroForm::TextField) then :text
        elsif field.is_a?(HexaPDF::Type::AcroForm::ButtonField) then :button
        elsif field.is_a?(HexaPDF::Type::AcroForm::ChoiceField) then :choice
        else :other
        end
        extracted << {name: field.full_field_name, type: type, alternate_name: field[:TU]}
      end
      extracted
    end

    def raw_field_names
      raw_fields.map { |f| f[:name] }
    end

    def any_raw_fields?
      raw_fields.any?
    end

    def fully_mapped?
      @unmapped_fields.empty?
    end

    def mapped_count
      @mapped_fields.size
    end

    def mapped_field_names
      @mapped_fields.values.uniq
    end

    # ------------------------------------------
    # PHASE 1: THE HIERARCHICAL COMPILER
    # ------------------------------------------
    def compile!
      puts ">> Compiling template: #{@template_path}"
      form = source_doc.acro_form(create: true)

      @mapped_fields = {}
      @unmapped_fields = []
      @select_field_options = {}
      @new_fields_detected = []

      page_text_map = {}
      source_doc.pages.each_with_index do |page, index|
        processor = AllTextProcessor.new
        page.process_contents(processor)
        page_text_map[index] = processor.text_chunks
      end

      section_map = build_section_map(page_text_map)

      form.each_field do |field|
        next unless field.is_a?(HexaPDF::Type::AcroForm::Field)

        widget = field.each_widget.first
        next unless widget && widget[:Rect]

        page_index = nil
        source_doc.pages.each_with_index do |page, idx|
          if page[:Annots]&.include?(widget)
            page_index = idx
            break
          end
        end

        next unless page_index

        is_btn = field.is_a?(HexaPDF::Type::AcroForm::ButtonField) || field.is_a?(HexaPDF::Type::AcroForm::ChoiceField)
        is_radio_group = is_btn && field.each_widget.count > 1

        options_map = nil

        if is_radio_group
          # THE FIX: Sort by Highest Y, then Leftmost X to guarantee finding the top-left box of multi-line groups
          first_widget = field.each_widget.min_by { |w| [-w[:Rect][1], w[:Rect][0]] }

          raw_label = find_nearest_text(page_text_map[page_index], first_widget[:Rect], mode: :group_label)

          if raw_label
            if raw_label.include?(":")
              raw_label = raw_label.split(":").first.strip
            elsif raw_label.downcase.include?("title")
              raw_label = "Title"
            end
          end

          options_map = {}
          field.each_widget do |w|
            next unless w[:Rect]

            opt_text = find_nearest_text(page_text_map[page_index], w[:Rect], mode: :button_option)

            if opt_text&.include?(":")
              opt_text = opt_text.split(":").last.strip
            end

            export_val = w[:AP]&.[](:N)&.value&.keys&.find { |k| k != :Off && k != :Off.to_s }

            if export_val
              ev_str = export_val.to_s.downcase
              is_generic = ["yes", "on", "off", "choice", "button", "group"].any? { |g| ev_str.include?(g) } || ev_str.match?(/^[0-9]+$/)

              final_key = if !is_generic && sanitize_key(export_val)
                sanitize_key(export_val).to_s
              else
                sanitized_opt = opt_text ? sanitize_key(opt_text)&.to_s : nil
                (sanitized_opt.nil? || sanitized_opt.empty?) ? ev_str : sanitized_opt
              end

              options_map[final_key] = export_val.to_s
            end
          end

        elsif field.is_a?(HexaPDF::Type::AcroForm::ButtonField)
          # Single-widget buttons are usually checkboxes. Build a predictable
          # hash so payload values can resolve to the exact export state.
          options_map = {}
          on_state = button_on_states(field).first
          if on_state
            on_export = on_state.to_s
            on_keys = ["yes", "true", "on", "1", "checked"]
            sanitized_on = sanitize_key(on_export)&.to_s
            on_keys << sanitized_on if sanitized_on && !sanitized_on.empty?
            on_keys.uniq.each { |k| options_map[k] = on_export }
          end

          ["no", "false", "off", "0", "unchecked"].each { |k| options_map[k] = "Off" }

        elsif field.is_a?(HexaPDF::Type::AcroForm::ChoiceField)
          # Choice fields can expose values via /Opt entries.
          options_map = {}
          if field[:Opt].is_a?(Array)
            field[:Opt].each do |opt|
              if opt.is_a?(Array)
                export_val = opt[0].to_s
                display_val = opt[1].to_s
                [export_val, display_val].each do |candidate|
                  normalized = sanitize_key(candidate)&.to_s
                  options_map[normalized] = export_val if normalized && !normalized.empty?
                end
              else
                export_val = opt.to_s
                normalized = sanitize_key(export_val)&.to_s
                options_map[normalized] = export_val if normalized && !normalized.empty?
              end
            end
          end
        else
          field_rect = widget[:Rect]
          raw_label = find_nearest_text(page_text_map[page_index], field_rect, mode: :standard)
        end

        y_center = if is_radio_group
          first_widget = field.each_widget.min_by { |w| [-w[:Rect][1], w[:Rect][0]] }
          (first_widget[:Rect][1] + first_widget[:Rect][3]) / 2.0
        else
          (widget[:Rect][1] + widget[:Rect][3]) / 2.0
        end

        active_section = get_active_section(section_map, page_index, y_center)

        target_key = nil

        # Apply overrides if applicable. Support @overrides keyed by
        # the original PDF field names (strings like "page0_field6"). When an
        # override exists, map the PDF field to the semantic :key declared in the
        # override (e.g. :full_name) so downstream validation uses semantic keys.
        affinity_entry = @overrides[field.full_field_name.to_s] || @overrides[field.full_field_name.to_sym]
        if affinity_entry
          mapped_semantic = affinity_entry[:key].to_sym
          target_key = is_btn ? :"#{mapped_semantic}_btn" : mapped_semantic

          # Ensure uniqueness when multiple fields map to the same semantic key
          original_target = target_key
          counter = 1
          while @mapped_fields.value?(target_key)
            target_key = :"#{original_target}_#{counter}"
            counter += 1
          end

          puts "   [Override] '#{field.full_field_name}' -> :#{target_key} (Affinity Native)"
        elsif raw_label
          base_key = sanitize_key(raw_label)
          unless base_key
            @unmapped_fields << field.full_field_name
            puts "   [Failed] Could not derive a valid key for field: #{field.full_field_name}"
            next
          end

          if is_btn
            base_key = normalize_button_base_key(base_key, options_map)
          end

          canonical_schema_key = canonical_schema_key_for(base_key, raw_label)
          if canonical_schema_key
            base_key = canonical_schema_key
          elsif !likely_noisy_key?(base_key)
            @new_fields_detected << base_key.to_s unless @new_fields_detected.include?(base_key.to_s)
          end

          target_key = active_section ? :"#{active_section}_#{base_key}" : base_key
          target_key = @overrides[raw_label].to_sym if @overrides[raw_label]
          target_key = :"#{target_key}_btn" if is_btn

          original_target = target_key
          counter = 1
          while @mapped_fields.value?(target_key)
            target_key = :"#{original_target}_#{counter}"
            counter += 1
          end
        end

        if target_key
          field[:T] = target_key.to_s
          @mapped_fields[field.full_field_name] = target_key

          if is_btn && options_map && options_map.any?
            @select_field_options[target_key.to_s] = options_map
            # Reuse TU to persist the mapping in the normalized template.
            field[:TU] = options_map.to_json
          end

          prefix_notice = active_section ? "[#{active_section.upcase}] " : ""
          puts "   [Auto-Mapped] #{prefix_notice}'#{raw_label || field.full_field_name}' -> :#{target_key}"

          if is_btn && options_map && options_map.any?
            puts "      └─ Valid Options Hash: #{options_map.keys.inspect}"
          end
        else
          @unmapped_fields << field.full_field_name
          puts "   [Failed] Could not find a text label for field: #{field.full_field_name}"
        end
      end

      source_doc.write(@normalized_path, optimize: true)
      puts ">> Compilation Complete. #{mapped_count} fields mapped."
      puts ">> Clean template saved to: #{@normalized_path}\n\n"

      {
        mapped: @mapped_fields,
        unmapped: @unmapped_fields,
        select_options: @select_field_options,
        new_fields_detected: @new_fields_detected
      }
    end

    # ------------------------------------------
    # PHASE 2: THE CRASH-PROOF INJECTOR
    # ------------------------------------------
    def fill!(payload, output_path, image_overlays = {})
      puts ">> Injecting data into: #{@normalized_path}"

      unless File.exist?(@normalized_path)
        raise "Normalized template missing. Please run compile! first."
      end

      validate_payload!(payload)

      normalized_doc = HexaPDF::Document.open(@normalized_path)
      form = normalized_doc.acro_form

      @filled_fields = {}
      @missing_fields = []

      payload.each do |key, value|
        next if value.nil?
        next if image_overlays.key?(key) # Silence the harmless warnings for image overlays

        doc_field = nil
        form.each_field do |f|
          if f.is_a?(HexaPDF::Type::AcroForm::Field) && f[:T].to_s == key.to_s
            doc_field = f
            break
          end
        end

        if doc_field
          begin
            if doc_field.is_a?(HexaPDF::Type::AcroForm::ButtonField) ||
                doc_field.is_a?(HexaPDF::Type::AcroForm::ChoiceField)
              resolved_from_map = false

              if doc_field[:TU]
                begin
                  options_map = JSON.parse(doc_field[:TU])
                  normalized_user_val = sanitize_key(value)&.to_s

                  if normalized_user_val && options_map.key?(normalized_user_val)
                    target_val = options_map[normalized_user_val]
                    doc_field.field_value = target_val
                    resolved_from_map = true

                    if doc_field.is_a?(HexaPDF::Type::AcroForm::ButtonField)
                      doc_field.each_widget do |w|
                        next unless w[:AP] && w[:AP][:N]
                        w_export = w[:AP][:N].value.keys.find { |k| k != :Off && k.to_s.downcase != "off" }
                        w[:AS] = (w_export.to_s == target_val.to_s) ? w_export : :Off
                      end
                    end
                  elsif doc_field.is_a?(HexaPDF::Type::AcroForm::ButtonField)
                    puts "   [Warning] :#{key} - '#{value}' not found in select options: #{options_map.keys.join(", ")}"
                  end
                rescue JSON::ParserError
                  resolved_from_map = false
                end
              end

              if resolved_from_map
                # done
              elsif doc_field.is_a?(HexaPDF::Type::AcroForm::ButtonField)
                normalized_val = value.to_s.downcase.strip
                on_state_sym = button_on_states(doc_field).first || :Yes

                if ["true", "yes", "on", "1"].include?(normalized_val)
                  doc_field.field_value = on_state_sym.to_s
                  doc_field.each_widget { |w| w[:AS] = on_state_sym }
                elsif ["false", "no", "off", "0"].include?(normalized_val)
                  doc_field.field_value = "Off"
                  doc_field.each_widget { |w| w[:AS] = :Off }
                else
                  doc_field.field_value = value.to_s
                end
              else
                doc_field.field_value = value.to_s
              end
            else
              if doc_field.key?(:MaxLen)
                doc_field[:Ff] = (doc_field[:Ff] || 0) & ~(1 << 24)
                doc_field.delete(:MaxLen)
              end
              doc_field.field_value = value.to_s
            end

            @filled_fields[key] = value
            puts "   [Filled] :#{key} = #{value}"
          rescue HexaPDF::Error => e
            puts "   [Warning] Rejected :#{key} - PDF formatting conflict (#{e.message.split(" (HexaPDF").first})"
          end
        else
          @missing_fields << key
          puts "   [Warning] Field :#{key} not found in template."
        end
      end

      image_overlays.each do |key, config|
        next unless payload[key] && File.exist?(payload[key])

        page_index = config[:page] || 0
        x, y, w, h = config[:coords]

        page = normalized_doc.pages[page_index]
        canvas = page.canvas(type: :overlay)

        canvas.fill_color(255, 255, 255)
        canvas.rectangle(x, y, w, h).fill
        canvas.image(File.open(payload[key]), at: [x, y], width: w, height: h)

        puts "   [Overlay] Stamped :#{key} onto page #{page_index}"
      end

      normalized_doc.write(output_path, optimize: true)
      puts ">> Success! Saved filled PDF to: #{output_path}\n\n"

      {filled: @filled_fields, missing: @missing_fields}
    end

    private

    def sanitize_key(string)
      key = string.to_s.downcase
        .gsub(/['*]/, "")
        .gsub(/[^a-z0-9]+/, "_").squeeze("_")
        .sub(/_$/, "")
        .sub(/^_/, "")

      # Merge common split artifacts from broken text extraction.
      loop do
        previous = key

        # Prefix split: "c_ertify" => "certify", "p_roperty" => "property".
        # Require at least 3 chars in the tail to avoid merging across real word boundaries.
        key = key.gsub(/(^|_)([a-z])_([a-z0-9]{3,})(?=_|$)/, '\\1\\2\\3')

        # Suffix split with trailing consonant: "an_d" => "and", "i_s" => "is".
        # Keep this narrow so valid tokens like "party_has" aren't corrupted.
        key = key.gsub(/(^|_)([a-z0-9]{1,2})_([bcdfghjklmnpqrstvwxyz])(?=_|$)/, '\\1\\2\\3')

        # Two-letter head split often seen in "th_at" => "that".
        key = key.gsub(/(^|_)(th|wh)_([a-z0-9]{2,})(?=_|$)/, '\\1\\2\\3')

        break if key == previous
      end

      key = fix_token_typos(key)

      key = canonicalize_known_label_key(key)

      return nil if key.empty?

      key.to_sym
    end

    def canonicalize_known_label_key(key)
      normalized = key.dup

      # Common fragmented tokens observed across vendor forms.
      replacements = {
        "t_ax" => "tax",
        "identi_cation" => "identification",
        "ide_ntity" => "identity",
        "othe_rbank" => "other_bank",
        "cha_r_ge" => "charge",
        "complet_e" => "complete",
        "a_nd" => "and",
        "ot_her" => "other",
        "sa_vings" => "savings",
        "aloan" => "a_loan",
        "tob_eused" => "to_be_used",
        "documen_tveri_edb_y" => "document_verified_by",
        "contac_tpersons" => "contact_persons",
        "modeof" => "mode_of",
        "mrmrs" => "mr_mrs",
        "mobile_n_o" => "mobile_no",
        "account_n_o" => "account_no",
        "name_of_authorized_ocial" => "name_of_authorized_official",
        "signature_of_authorized_ocial" => "signature_of_authorized_official",
        "na_onal_id" => "national_id",
        "posi_on_title" => "position_title",
        "contribu_on" => "contribution",
        "con_rmed" => "confirmed"
      }

      replacements.each do |from, to|
        normalized = normalized.gsub(from, to)
      end

      # Canonicalize the recurring long disclaimer/attestation label that often
      # arrives with fragmented tokens across different PDFs.
      if normalized.include?("certify_that_my") &&
          normalized.include?("savings_balance") &&
          normalized.include?("sole_property") &&
          normalized.include?("other_party") &&
          normalized.include?("claim_over_it")
        return "certify_that_my_pledged_tier3_other_savings_balance_is_my_sole_property_and_that_no_other_party_has_a_claim_over_it"
      end

      # Canonicalize a frequent long employer-loan question variant.
      if normalized.include?("does_the_employer") &&
          normalized.include?("loan") &&
          normalized.include?("lien") &&
          normalized.include?("recovered") &&
          normalized.include?("employer_contribution")
        return "does_the_employer_have_a_loan_lien_to_be_recovered_from_employer_contribution"
      end

      normalized
    end

    def fix_token_typos(key)
      normalized = key.dup

      FormStencil::Constants::TYPO_PHRASE_REPLACEMENTS.each do |from, to|
        normalized = normalized.gsub(from, to)
      end

      # Clean up repeated separators introduced during replacement.
      normalized.squeeze("_").sub(/^_/, "").sub(/_$/, "")
    end

    def build_section_map(page_text_map)
      map = {}
      page_text_map.each do |page_idx, chunks|
        page_sections = []
        chunks.each do |chunk|
          clean_chunk = chunk[:text].downcase.gsub(/[^a-z]/, "")

          if @sections.any? { |s| clean_chunk == s.downcase.gsub(/[^a-z]/, "") }
            matched_section = @sections.find { |s| clean_chunk == s.downcase.gsub(/[^a-z]/, "") }
            clean_section = (matched_section.downcase == "adress details") ? "Address Details" : matched_section
            page_sections << {key: sanitize_key(clean_section), y_min: chunk[:y_min]}
          end
        end
        map[page_idx] = page_sections.sort_by { |s| -s[:y_min] }
      end
      map
    end

    def button_on_states(field)
      states = []

      field.each_widget do |w|
        next unless w[:AP] && w[:AP][:N]

        keys = w[:AP][:N].value.keys
        keys.each do |k|
          next if k == :Off || k.to_s.downcase == "off"

          states << k
        end
      end

      states.uniq
    end

    def normalize_button_base_key(base_key, options_map)
      return base_key unless options_map.is_a?(Hash) && options_map.any?

      option_keys = options_map.keys.map { |k| sanitize_key(k)&.to_s }.compact.uniq

      title_tokens = %w[dr mr mrs miss title]
      if (option_keys & title_tokens).size >= 2
        return :title
      end

      if option_keys.include?("male") && option_keys.include?("female")
        return :gender
      end

      marital_tokens = %w[single married divorced widow_widower widowed]
      if (option_keys & marital_tokens).size >= 2
        return :marital_status
      end

      base_key
    end

    def schema_variations(canonical_key)
      entry = @schema[canonical_key]
      return [] unless entry
      entry.is_a?(Hash) ? Array(entry[:variations]) : Array(entry)
    end

    def canonical_schema_key_for(base_key, raw_label)
      candidates = []
      candidates << base_key.to_s if base_key
      candidates << sanitize_key(raw_label).to_s if raw_label && sanitize_key(raw_label)

      @schema.each do |canonical, _info|
        variations = schema_variations(canonical)
        canonical_key = sanitize_key(canonical.to_s)&.to_s
        return canonical if candidates.include?(canonical_key)

        variations.each do |label|
          normalized = sanitize_key(label)&.to_s
          next unless normalized

          return canonical if candidates.include?(normalized)
        end
      end

      nil
    end

    def likely_noisy_key?(key)
      str = key.to_s
      return true if str.empty?

      str.match?(/(?:^|_)image\d+|(?:^|_)text\d+|(?:^|_)page\d+_field\d+/)
    end

    def get_active_section(section_map, page_idx, field_y_center)
      return nil unless section_map[page_idx]
      active_section = nil
      section_map[page_idx].each do |sec|
        if sec[:y_min] > field_y_center
          active_section = sec[:key]
        else
          break
        end
      end
      active_section
    end

    def validate_payload!(payload)
      payload.each do |key, value|
        next if value.nil? || value.to_s.empty?

        # Strip suffixes like _1 or _btn to find the base canonical key for schema lookup
        key_str = key.to_s
        base_key = key_str.sub(/_btn(?:_\d+)?\z/, "").sub(/_\d+\z/, "").to_sym

        # Try to resolve override info. @overrides may be keyed by
        # original PDF field names (strings like "page0_field6") so allow lookup
        # by semantic base_key (matching value[:key]) or by string key.
        affinity_info = @overrides[base_key] || @overrides[base_key.to_s] || @overrides.values.find { |v| v.is_a?(Hash) && v[:key].to_sym == base_key }

        type_info = @schema[base_key]

        # If it's a button field, it's a select type by nature
        type = if key_str.include?("_btn")
          :select
        elsif affinity_info
          affinity_info[:type]
        elsif type_info
          type_info.is_a?(Hash) ? type_info[:type] : :string
        else
          infer_type(key)
        end

        schema_options = if type_info.is_a?(Hash)
          type_info[:options] || []
        else
          []
        end
        pdf_options = @select_field_options[key.to_s]&.keys || []

        allowed_options = (schema_options + pdf_options).uniq

        unless FormStencil::Validator.valid?(value, type, allowed_options)
          msg = "Validation failed for field :#{key} (base: :#{base_key}): Expected #{type}, got '#{value}'."
          msg += " (Allowed options: #{allowed_options.join(", ")})" if type == :select
          raise FormStencil::ValidationError, msg
        end
      end
    end

    def infer_type(key)
      tokens = key.to_s.downcase.split("_")
      if (tokens & %w[date dob expiry]).any?
        :date
      elsif (tokens & %w[amount salary income balance]).any?
        :money
      elsif (tokens & %w[email]).any?
        :email
      elsif (tokens & %w[tenor years age]).any?
        :number
      else
        :string
      end
    end

    # ------------------------------------------
    # THE UNIVERSAL DYNAMIC HEURISTIC (WEIGHTS FIXED)
    # ------------------------------------------
    def find_nearest_text(text_chunks, field_rect, mode: :standard)
      f_x_min, f_y_min, f_x_max, f_y_max = field_rect
      f_y_center = (f_y_min + f_y_max) / 2.0

      best_text = nil
      best_score = 99999

      text_chunks.each do |chunk|
        t_x_min = chunk[:x_min]
        t_x_max = chunk[:x_max]
        t_x_center = (t_x_min + t_x_max) / 2.0
        t_y_min = chunk[:y_min]
        t_y_max = chunk[:y_max]
        t_y_center = (t_y_min + t_y_max) / 2.0

        dx_left = f_x_min - t_x_max
        dx_right = t_x_min - f_x_max
        dy_top = t_y_min - f_y_max
        dy_center = (t_y_center - f_y_center).abs

        score = nil
        is_section_header = @sections.any? { |s| chunk[:text].downcase.gsub(/[^a-z]/, "") == s.downcase.gsub(/[^a-z]/, "") }
        has_colon_or_q = chunk[:text].strip.match?(/[:?]\z/)

        case mode
        when :button_option
          if dy_center < 12
            if dx_right > -10 && dx_right < 60
              score = dx_right.abs
            elsif dx_left > -10 && dx_left < 60
              score = dx_left.abs + 5
            end
          end

        when :group_label
          if dy_center < 15 && dx_left > -20 && dx_left < 300
            score = dx_left.abs - 1000
            score -= 300 if has_colon_or_q # Colon Tie-breaker Bonus
          elsif dy_top > -5 && dy_top < 30 && (t_x_max > f_x_min - 20)
            score = dy_top.abs + 50
            score -= 300 if has_colon_or_q
          end

        when :standard
          is_grid_locked = dy_top > -5 && dy_top < 30 && t_x_center >= (f_x_min - 20) && t_x_center <= (f_x_max + 20)
          is_inline = dy_center < 10 && dx_left > -10 && dx_left < 200

          if is_grid_locked
            score = dy_top.abs - 2000
            score -= 200 if has_colon_or_q
          elsif is_inline
            score = dx_left.abs - 1000
            score -= 200 if has_colon_or_q
          elsif dy_center < 15 && dx_left > -10 && dx_left < 150
            score = dx_left.abs
            score -= 200 if has_colon_or_q
          end
        end

        if score
          score += 10000 if is_section_header

          if score < best_score
            best_score = score
            best_text = chunk[:text]
          end
        end
      end

      best_text&.sub(/:\z/, "")&.strip
    end
  end
end
