module Gurobi
module Attribute
  class << self
    # @param name [String]
    # @return [CharAttr, DoubleAttr, IntAttr, StringAttr]
    def by_name(name)
      @_by_name ||= Hash[
        [
          GRB::CharAttr,
          GRB::DoubleAttr,
          GRB::IntAttr,
          GRB::StringAttr,
        ].flat_map do |mod|
          mod.constants.map do |constant_name|
            [constant_name, mod.const_get(constant_name)]
          end
        end
      ]

      name = name.to_sym if name.respond_to?(:to_sym)
      @_by_name[name] or
        raise Error, "invalid gurobi attribute name: #{name.inspect}"
    end
  end

  # Creates attribute accessors
  #
  # @param delegate [Symbol]
  # @param attributes [Array<String>]
  # @return [void]
  # @see http://www.gurobi.com/documentation/5.0/reference-manual/node652
  def attributes(delegate, attributes)
    attributes.each_slice(3) do |name, method, settable|
      attr = "#{Attribute.by_name(name).class.name}::#{name}"

      if method[-1] == ??
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{method}
            #{delegate}.get(#{attr}) != 0
          end
        EOS
      else
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{method}
            #{delegate}.get(#{attr})
          end
        EOS
      end

      if settable == 'Yes'
        class_eval(<<-EOS, __FILE__, __LINE__ + 1)
          def #{method}=(value)
            #{delegate}.set(#{attr}, value)
          end
        EOS
      end
    end
  end
end
end
