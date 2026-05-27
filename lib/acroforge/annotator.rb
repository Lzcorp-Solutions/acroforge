# frozen_string_literal: true

require "yaml"
require "hexapdf"

module AcroForge
  # Overlays a labeled badge on every AcroForm field in a PDF so a human
  # can correlate cryptic field names (page0_field6) to what's visible on
  # the page. The badge optionally shows the proposed semantic key from a
  # mapping file, with colour-coding for mapped vs. unmapped entries.
  module Annotator
    module_function

    MAPPED_COLOR = "1f7a3a"  # green: in mapping with a key set
    UNMAPPED_COLOR = "c2410c"  # amber: in mapping with key: nil
    MISSING_COLOR = "6b7280"  # gray: not in mapping at all
    BARE_COLOR = "1f3a8a"  # blue: no mapping supplied at all

    def annotate(pdf_path, out:, mapping: nil)
      entries = mapping ? load_mapping(mapping) : nil

      doc = HexaPDF::Document.open(pdf_path)
      form = doc.acro_form(create: false)
      raise RelabelError, "PDF has no AcroForm: #{pdf_path}" unless form

      annotated = 0
      mapped_count = 0
      unmapped_count = 0
      missing_count = 0

      form.each_field do |field|
        field.each_widget do |widget|
          next unless widget[:Rect]
          page = find_page_for_widget(doc, widget)
          next unless page

          original_name = field.full_field_name
          entry = entries&.[](original_name)

          color, label = if entries.nil?
            [BARE_COLOR, original_name]
          elsif entry.nil?
            missing_count += 1
            [MISSING_COLOR, "#{original_name} (not in mapping)"]
          elsif entry["key"].nil? || entry["key"].to_s.empty?
            unmapped_count += 1
            [UNMAPPED_COLOR, "#{original_name} (no key)"]
          else
            mapped_count += 1
            [MAPPED_COLOR, "#{original_name} -> #{entry["key"]}"]
          end

          draw_badge(page, widget[:Rect], label, color)
          annotated += 1
        end
      end

      doc.write(out)

      {
        annotated: annotated,
        mapped: mapped_count,
        unmapped: unmapped_count,
        missing: missing_count,
        out_path: out
      }
    end

    def find_page_for_widget(doc, widget)
      doc.pages.find { |page| page[:Annots]&.include?(widget) }
    end

    def load_mapping(arg)
      return arg if arg.is_a?(Hash)
      data = YAML.load_file(arg) || {}
      data.reject { |k, _| k.to_s.start_with?("_") }
    end

    # Draw a coloured badge near the field rectangle showing the label text.
    #
    # Placement heuristic:
    #   - Text input (wide rectangle with enough height): badge goes INSIDE
    #     the field's empty input area. This is "free space" before the form
    #     is filled and never collides with the form's own labels or
    #     neighboring fields.
    #   - Small field (checkbox / radio): too small to host a badge inside,
    #     so the badge sits ABOVE the field. The form's label for these is
    #     typically to the right of the box, so above doesn't collide.
    def draw_badge(page, rect, label, color_hex)
      x1, y1, x2, y2 = rect.to_a
      width = x2 - x1
      height = y2 - y1

      canvas = page.canvas(type: :overlay)

      # Outline around the field so each badge is tied visually to its field,
      # even when the badge sits inside an empty input.
      canvas.save_graphics_state do
        canvas.stroke_color(color_hex)
        canvas.line_width(0.75)
        canvas.rectangle(x1 - 1, y1 - 1, width + 2, height + 2).stroke
      end

      page_box = page.box(:media)
      badge_h = 10
      char_width = 3.6
      max_width = page_box.width - x1 - 4
      badge_w = [(label.length * char_width) + 6, max_width].min

      fits_inside = width > height * 1.5 && height >= badge_h + 2

      badge_x, badge_y = if fits_inside
        # Inside the field, top-aligned, clipped to the field width
        inside_w = [badge_w, width - 2].min
        [x1 + 1, y2 - badge_h - 1].tap { |_| badge_w = inside_w }
      else
        # Above the small field; clamp to page top if needed
        above_y = y2 + 1
        below_y = y1 - badge_h - 1
        candidate = (above_y + badge_h <= page_box.top) ? above_y : below_y
        [x1, candidate.clamp(0, page_box.top - badge_h)]
      end

      canvas.save_graphics_state do
        canvas.fill_color(color_hex)
        canvas.opacity(fill_alpha: fits_inside ? 0.85 : 0.9)
        canvas.rectangle(badge_x, badge_y, badge_w, badge_h).fill
      end

      canvas.save_graphics_state do
        canvas.fill_color("ffffff")
        canvas.font("Helvetica", size: 6.5)
        canvas.text(label, at: [badge_x + 3, badge_y + 2.5])
      end
    end
  end
end
