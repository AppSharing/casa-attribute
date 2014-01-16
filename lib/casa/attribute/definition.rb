module CASA
  module Attribute
    class Definition

      class << self

        def attribute_class_var_name attribute_name

          "@@attribute_#{attribute_name}".to_sym

        end

        def attribute attribute_name, attribute_value

          attribute_class_var = class_variable_get attribute_class_var_name attribute_name
          attribute_class_var[name] = attribute_value if attribute_value
          attribute_class_var[name]

        end

        def support_attribute attribute_name

          class_variable_set attribute_class_var_name(attribute_name), {}

          self.class.send :define_method, attribute_name.to_sym do |attribute_value = nil|
            attribute attribute_name, attribute_value
          end

          define_method(attribute_name.to_sym) do
            self.class.send attribute_name.to_sym
          end

        end

        def operation_class_var_name operation_name

          "@@operation_#{operation_name}".to_sym

        end

        def operation operation_name, proc, block

          operations = class_variable_get operation_class_var_name operation_name

          if proc
            operations[name] = proc
          elsif block
            operations[name] = block
          end

          operations[name]

        end

        def support_operation operation_name

          class_variable_set "@@operation_#{operation_name}", {}

          self.class.send :define_method, operation_name do |proc = nil, &block|
            operation operation_name, proc, block
          end

          define_method(operation_name.to_sym) do |payload|
            run_handler operation_name, payload
          end

        end

      end

      attr_reader :name
      attr_reader :options

      def initialize name, options = nil

        @name = name
        @options = options ? options : {}

        @handlers = {}
        ['squash','filter','transform'].each do |operation|
          registered = self.class.class_variable_get("@@operation_#{operation}")
          class_name = self.class.name
          if registered.include?(class_name) and registered[class_name].is_a?(Class)
            @handlers[operation] = registered[class_name].new(self, @options.has_key?(operation) ? @options[operation] : nil)
          end
        end

      end

      def run_handler operation, payload
        if @handlers.include? operation
          @handlers[operation].process(payload)
        else
          klass = self.class
          instance_exec payload.to_hash, &(klass.class_variable_get(klass.operation_class_var_name operation)[klass.name])
        end
      end

      ['uuid','section'].each { |attribute| support_attribute attribute }

      ['squash','filter','transform'].each { |operation| support_operation operation }

      # invoke within child class definition as any of:
      #
      #   class MySquashHandler < ::CASA::Operation::Strategy
      #     def initialize definition, options = nil
      #       # do whatever
      #     end
      #     def process payload
      #       # return processed payload attribute (or bool in filter case)
      #     end
      #   end
      #   squash MySquashHandler
      #
      #   ----
      #
      #   squash do |payload|
      #     routine
      #   end
      #
      #   ----
      #
      #   squash Proc.new { |payload| routine }
      #

    end
  end
end