require 'forwardable'

module Gurobi
class Env
  java_import 'gurobi.GRBEnv'

  extend Forwardable

  class << self
    # @param name [Symbol, String]
    # @return [DoubleParam, IntParam, StringParam]
    def param_by_name(name)
      @_param_by_name ||= Hash[
        [
          GRB::DoubleParam,
          GRB::IntParam,
          GRB::StringParam,
        ].flat_map do |mod|
          mod.constants.map do |constant_name|
            [constant_name, mod.const_get(constant_name)]
          end
        end
      ]

      name = name.to_sym if name.respond_to?(:to_sym)
      @_param_by_name[name] or
        raise Error, "invalid gurobi parameter name: #{name.inspect}"
    end

    # @param (see #get)
    # @param value [#to_f, #to_i, #to_s]
    # @return [Float, Fixnum, String]
    def cast_param_value(param, value)
      case param; when Symbol, String
        param = param_by_name(param)
      end

      case param
      when GRB::DoubleParam; value.to_f
      when GRB::IntParam;    value.to_i
      when GRB::StringParam; value.to_s
      else raise Error, "invalid gurobi parameter: #{param.inspect}"
      end
    end
  end

  # @return [GRBEnv]
  attr_reader :grb_env

  def_delegators :grb_env,
    :dispose, :error_msg, :message, :release,
    :read_params, :reset_params, :write_params

  def initialize(*args)
    @grb_env = GRBEnv.new(*args)
  end

  # @param param [DoubleParam, IntParam, StringParam, Symbol, String]
  # @return [Float, Fixnum, String]
  def get(param)
    case param; when Symbol, String
      param = self.class.param_by_name(param)
    end

    @grb_env.get(param)
  end

  # @param param [DoubleParam, IntParam, StringParam, Symbol, String, Hash]
  # @param value [Float, Fixnum, String]
  # @return [void]
  def set(param, value = nil)
    if param.is_a?(Hash)
      param.each do |_param, _value|
        set(_param, _value)
      end
      return
    end

    raise Error, "invalid param value: #{value.inspect}" unless value

    case param; when Symbol, String
      param = self.class.param_by_name(param)
    end

    @grb_env.set(param, value)
  end

  # @param (see #get)
  # @return [Array<Float, Fixnum, String>]
  def param_info(param)
    case param; when Symbol, String
      param = self.class.param_by_name(param)
    end

    type = param.class.name[/(\w+)(?=Param$)/].downcase
    info = Java.send(type)[4].new
    @grb_env.get_param_info(param, info)
    info.to_a
  end
end
end
