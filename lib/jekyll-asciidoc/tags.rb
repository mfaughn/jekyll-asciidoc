module Jekyll
  module Tags
    class AsciiDocIncludeTag < IncludeTag
      def initialize(tag_name, file, tokens)
        super
        @file = file.strip
      end
      
      def asciidocify context, input, doctype = nil
        (context.registers[:cached_asciidoc_converter] ||= (Jekyll::AsciiDoc::Converter.get_instance context.registers[:site]))
          .convert(doctype ? %(:doctype: #{doctype}#{Utils::NewLine}#{input}) : (input || ''))
      end
      
      def load_cached_partial(path, context)
        context.registers[:cached_partials] ||= {}
        cached_partial = context.registers[:cached_partials]

        if cached_partial.key?(path)
          cached_partial[path]
        else
          html = asciidocify(context, File.read(path))
          unparsed_file = context.registers[:site]
            .liquid_renderer
            .file(path)
          begin
            cached_partial[path] = unparsed_file.parse(html)
          rescue => e
            e.template_name = path
            e.markup_context = "asciidoc " if e.markup_context.nil?
            raise e
          end
        end
      end

      def render(context)
        if @file !~ /^[a-zA-Z0-9_\/\.-]+$/ || @file =~ /\.\// || @file =~ /\/\./
          return "Include file '#{@file}' contains invalid characters or sequences"
        end
        return "File must have \".adoc\" or \".asciidoc\" extension" if @file !~ /\.(adoc|asciidoc)$/
        
        site = context.registers[:site]
        path = locate_include_file(context, @file, site.safe)
        return unless path
        add_include_to_dependency(site, path, context)
        
        partial = load_cached_partial(path, context)

        context.stack do
          begin
            partial.render!(context)
          rescue Liquid::Error => e
            e.template_name = path
            e.markup_context = "included " if e.markup_context.nil?
            raise e
          end
        end
      end

    end # AsciidocIncludeTag
  end # Tags
end # Jekyll
Liquid::Template.register_tag('adoc', Jekyll::Tags::AsciiDocIncludeTag)
