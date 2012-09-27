module Gurobi
  module Operator
    EXPR_OPERATORS = %w(
      + plus
      - minus
      * mul
    )
    CONSTR_OPERATORS = %w(
      === eq
      <=  le
      >=  ge
    )

    def self.included(klass)
      klass.class_eval do
        (EXPR_OPERATORS + CONSTR_OPERATORS).each_slice(2) do |operator, method|
          with_method    = "#{method}_with_gurobi"
          without_method = "#{method}_without_gurobi"
          if method_defined?(without_method)
            alias_method operator, without_method
          end
          alias_method without_method, operator
          alias_method operator, with_method
        end
      end
    end

    EXPR_OPERATORS.each_slice(2) do |operator, method|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{method}_with_gurobi(other)
          case other
          when LinExpr, Var
            other #{operator} self
          else
            #{method}_without_gurobi(other)
          end
        end
      EOS
    end

    CONSTR_OPERATORS.each_slice(2) do |operator, method|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{method}_with_gurobi(other)
          case other
          when LinExpr, Var
            Constr.new(self, '#{operator[0]}', other)
          else
            #{method}_without_gurobi(other)
          end
        end
      EOS
    end
  end
end

class Fixnum
  include Gurobi::Operator
end

class Float
  include Gurobi::Operator
end
