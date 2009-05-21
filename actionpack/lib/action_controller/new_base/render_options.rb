module ActionController
  module RenderOptions
    extend ActiveSupport::DependencyModule
    
    included do
      extlib_inheritable_accessor :_renderers
      self._renderers = []
    end
    
    module ClassMethods
      def _write_render_options
        renderers = _renderers.map do |r|
          <<-RUBY_EVAL
            if options.key?(:#{r})
              _process_options(options)
              return _render_#{r}(options[:#{r}], options)
            end
          RUBY_EVAL
        end
        
        class_eval <<-RUBY_EVAL, __FILE__, __LINE__ + 1
          def _handle_render_options(options)
            #{renderers.join}
          end
        RUBY_EVAL
      end
      
      def _add_render_option(name)
        _renderers << name
        _write_render_options
      end
    end
    
    def render_to_body(options)
      _handle_render_options(options) || super
    end
  end
  
  module RenderOption
    extend ActiveSupport::DependencyModule

    included do
      extend ActiveSupport::DependencyModule
      depends_on RenderOptions

      def self.register_renderer(name)
        included { _add_render_option(name) }
      end
    end
  end

  module Renderers
    module Json
      include RenderOption
      register_renderer :json
      
      def _render_json(json, options)
        json = ActiveSupport::JSON.encode(json) unless json.respond_to?(:to_str)
        json = "#{options[:callback]}(#{json})" unless options[:callback].blank?
        response.content_type ||= Mime::JSON
        self.response_body = json
      end      
    end

    module Xml
      include RenderOption
      register_renderer :xml

      def _render_xml(xml, options)
        response.content_type ||= Mime::XML
        self.response_body  = xml.respond_to?(:to_xml) ? xml.to_xml : xml
      end
    end
  end
end