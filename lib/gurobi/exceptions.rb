module Gurobi
  class MustNotHappen < Exception; end
  class Error < StandardError; end

  # @see http://www.gurobi.com/documentation/5.0/reference-manual/node372
  class NativeError < Error
    class << self
      # @param (see #initialize)
      # @return [NativeError]
      def create(grb_exception)
        @_classes ||= Hash[
          constants.map do |constant_name|
            klass = const_get(constant_name)
            [klass.const_get(:CODE), klass] if klass.const_defined?(:CODE)
          end.compact
        ]
        (@_classes[grb_exception.error_code] || Unknown).new(grb_exception)
      end
    end

    # @return [GRBException]
    attr_reader :grb_exception

    # @param grb_exception [GRBException]
    def initialize(grb_exception)
      super(grb_exception.message)
      set_backtrace(grb_exception.backtrace)
      @grb_exception = grb_exception
    end

    GRB::Error.constants.each do |constant_name|
      klass = const_set(constant_name, Class.new(self))
      klass.const_set(:CODE, GRB::Error.const_get(constant_name))
    end
    class Unknown < self; end
  end
end
