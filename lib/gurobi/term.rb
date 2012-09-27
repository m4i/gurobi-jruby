module Gurobi
class Term
  # @return [Float, Fixnum]
  attr_reader :coeff

  # @return [Gurobi::Var]
  attr_reader :var

  # @param coeff [Float, Fixnum]
  # @param var [Gurobi::Var]
  def initialize(coeff, var)
    @coeff = coeff
    @var   = var
  end

  # @return [String]
  def inspect
    (@coeff == 1 ? '' : "#@coeff ") + @var.inspect
  end
end
end
