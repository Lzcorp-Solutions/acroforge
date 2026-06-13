# frozen_string_literal: true

module AcroForge
  ImageTooLargeError = Class.new(Error)
  UnsupportedImageFormatError = Class.new(Error)

  # Stamps JPG/PNG files into AcroForm widget rectangles.
  class ImageStamper
    # Caps a phone-camera passport photo from bloating the output PDF.
    MAX_IMAGE_BYTES = 5 * 1024 * 1024
    MAX_IMAGE_DIMENSION = 4000
    # Auto-downsample images whose pixel resolution far exceeds this PPI
    # at the widget's rendered size. Requires ImageMagick on PATH.
    TARGET_PPI = 200

    def stamp!(doc, field, path)
      format, image_width, image_height = validate_image!(path)
      widget = field.each_widget.first
      return unless widget && widget[:Rect]

      page = doc.pages.find { |candidate_page| candidate_page[:Annots]&.include?(widget) }
      return unless page

      # Widget Rect is absolute page coords; canvas API is MediaBox-relative.
      media_box_x, media_box_y = page.box.value[0], page.box.value[1]
      rect_x_min, rect_y_min, rect_x_max, rect_y_max = widget[:Rect]
      slot_width = rect_x_max - rect_x_min
      slot_height = rect_y_max - rect_y_min
      slot_canvas_x = rect_x_min - media_box_x
      slot_canvas_y = rect_y_min - media_box_y

      stamp_path = prepare_image_for_slot(path, format, image_width, image_height,
        slot_width, slot_height) || path
      if stamp_path != path
        _, image_width, image_height = image_dimensions(stamp_path)
      end

      draw_width, draw_height = fit_inside(image_width, image_height, slot_width, slot_height)
      draw_x = slot_canvas_x + (slot_width - draw_width) / 2.0
      draw_y = slot_canvas_y + (slot_height - draw_height) / 2.0

      canvas = page.canvas(type: :overlay)
      canvas.fill_color(255, 255, 255)
      canvas.rectangle(slot_canvas_x, slot_canvas_y, slot_width, slot_height).fill
      canvas.image(stamp_path, at: [draw_x, draw_y], width: draw_width, height: draw_height)

      # Bake into the page so the widget's empty appearance doesn't repaint over the image.
      page[:Annots].delete(widget)
    end

    # Trust boundary in front of ImageMagick: any malformed-input path
    # raises a single error class so worker retry policies can key on it.
    def validate_image!(path)
      size = File.size(path)
      if size > MAX_IMAGE_BYTES
        raise ImageTooLargeError, "#{path}: #{size} bytes exceeds #{MAX_IMAGE_BYTES} byte cap"
      end
      format, width, height = image_dimensions(path)
      if width > MAX_IMAGE_DIMENSION || height > MAX_IMAGE_DIMENSION
        raise ImageTooLargeError,
          "#{path}: #{width}x#{height}px exceeds #{MAX_IMAGE_DIMENSION}px per side"
      end
      [format, width, height]
    end

    private

    def fit_inside(image_width, image_height, slot_width, slot_height)
      scale = [slot_width.to_f / image_width, slot_height.to_f / image_height].min
      [image_width * scale, image_height * scale]
    end

    # Trim removes the transparent border around a signature; downsample
    # caps source resolution at TARGET_PPI for the widget's longer side.
    def prepare_image_for_slot(path, format, image_width, image_height,
      slot_width_pt, slot_height_pt)
      return nil unless imagemagick_available?
      slot_max_pt = [slot_width_pt, slot_height_pt].max
      target_max_px = (slot_max_pt * TARGET_PPI / 72.0).ceil
      needs_resize = image_width > target_max_px * 2 || image_height > target_max_px * 2
      needs_trim = format == :png && png_with_alpha?(path)
      return nil unless needs_resize || needs_trim

      ext = (format == :png) ? ".png" : ".jpg"
      require "securerandom"
      require "tmpdir"
      output_path = File.join(Dir.tmpdir,
        "acroforge_stamp_#{Process.pid}_#{SecureRandom.hex(4)}#{ext}")
      # `format:path` locks the coder, closing the CVE-2016-3714 (ImageTragick) class of attack.
      args = ["convert", "#{format}:#{path}"]
      args.push("-trim", "+repage") if needs_trim
      args.push("-resize", "#{target_max_px}x#{target_max_px}>") if needs_resize
      args.push(output_path)
      success = system(*args, out: File::NULL, err: File::NULL)
      (success && File.exist?(output_path)) ? output_path : nil
    end

    # PNG color type 4 = greyscale+alpha, 6 = RGBA — only these are trim-worthy.
    def png_with_alpha?(path)
      File.open(path, "rb") do |io|
        return false unless io.read(8) == "\x89PNG\r\n\x1A\n".b
        return false if io.read(8).nil?
        return false if io.read(8).nil?
        return false if io.read(1).nil?
        color_type_byte = io.read(1)
        return false if color_type_byte.nil?
        color_type = color_type_byte.unpack1("C")
        color_type == 4 || color_type == 6
      end
    end

    def imagemagick_available?
      return @imagemagick_available if defined?(@imagemagick_available)
      @imagemagick_available = system("which", "convert", out: File::NULL, err: File::NULL)
    end

    def image_dimensions(path)
      File.open(path, "rb") do |io|
        head = read_exact(io, 8, path)
        io.rewind
        if head.start_with?("\x89PNG\r\n\x1A\n".b)
          width, height = read_png_dimensions(io, path)
          [:png, width, height]
        elsif head[0, 2] == "\xFF\xD8".b
          width, height = read_jpeg_dimensions(io, path)
          [:jpg, width, height]
        else
          raise_unsupported(path)
        end
      end
    end

    def read_png_dimensions(io, path)
      read_exact(io, 16, path) # 8-byte signature + 4 length + "IHDR"
      width = read_exact(io, 4, path).unpack1("N")
      height = read_exact(io, 4, path).unpack1("N")
      [width, height]
    end

    def read_jpeg_dimensions(io, path)
      read_exact(io, 2, path) # SOI
      loop do
        marker_byte = read_exact(io, 1, path).getbyte(0)
        raise_unsupported(path) unless marker_byte == 0xFF
        # Runs of 0xFF are valid JPEG fill bytes between markers.
        marker_code = read_exact(io, 1, path).getbyte(0)
        marker_code = read_exact(io, 1, path).getbyte(0) while marker_code == 0xFF
        raise_unsupported(path, "no SOF marker found") if marker_code == 0xD9 || marker_code == 0x00
        # 0xD0..0xD7 and 0x01 are standalone markers — no length follows.
        next if (0xD0..0xD7).cover?(marker_code) || marker_code == 0x01
        segment_length = read_exact(io, 2, path).unpack1("n")
        raise_unsupported(path, "negative segment length") if segment_length < 2
        is_sof_marker = (0xC0..0xCF).cover?(marker_code) && ![0xC4, 0xC8, 0xCC].include?(marker_code)
        if is_sof_marker
          read_exact(io, 1, path) # precision
          height = read_exact(io, 2, path).unpack1("n")
          width = read_exact(io, 2, path).unpack1("n")
          return [width, height]
        else
          read_exact(io, segment_length - 2, path)
        end
      end
    end

    def read_exact(io, byte_count, path)
      buf = io.read(byte_count)
      raise_unsupported(path, "truncated header") if buf.nil? || buf.bytesize < byte_count
      buf
    end

    def raise_unsupported(path, reason = "only JPG and PNG are supported")
      raise UnsupportedImageFormatError, "#{path}: #{reason}"
    end
  end
end
