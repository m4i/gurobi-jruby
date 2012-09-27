module Gurobi
class LinExpr
  java_import 'gurobi.GRBLinExpr'

  # @return [Array<Gurobi::Term>]
  attr_reader :terms

  # @return [Float, Fixnum]
  attr_reader :constant

  # @param terms [Array<Gurobi::Term>]
  # @param constant [Float, Fixnum]
  def initialize(terms, constant = 0)
    @terms    = terms
    @constant = constant
  end

  # @return [Gurobi::LinExpr]
  def -@
    self * -1
  end

  # @param other [Gurobi::LinExpr, Gurobi::Var, Float, Fixnum]
  # @return [Gurobi::LinExpr]
  def +(other)
    case other
    when LinExpr
      self.class.new(@terms + other.terms, @constant + other.constant)
    when Var
      self + other.to_lin_expr
    else
      self.class.new(@terms, @constant + other)
    end
  end

  # @param (see #+)
  # @return [Gurobi::LinExpr]
  def -(other)
    self + (- other)
  end

  # @param other [Float, Fixnum]
  # @return [Gurobi::LinExpr]
  def *(other)
    unless other.is_a?(Float) || other.is_a?(Fixnum)
      raise Error, "invalid argument: #{other.inspect}"
    end
    self.class.new(
      @terms.map {|term| Term.new(term.coeff * other, term.var) },
      @constant * other
    )
  end

  # @param rhs [Gurobi::LinExpr, Gurobi::Var, Float, Fixnum]
  # @return [Gurobi::Constr]
  def ===(rhs)
    Constr.new(self, GRB::EQUAL, rhs)
  end

  # (see #===)
  def <=(rhs)
    Constr.new(self, GRB::LESS_EQUAL, rhs)
  end

  # (see #===)
  def >=(rhs)
    Constr.new(self, GRB::GREATER_EQUAL, rhs)
  end

  # @return [String]
  def inspect
    buffer = @terms.map(&:inspect).join(' + ')
    if buffer.empty?
      buffer << @constant.inspect
    else
      buffer << " + #{@constant.inspect}" unless @constant == 0
    end
    buffer
  end

  private

  # @return [GRBLinExpr]
  def to_gurobi
    GRBLinExpr.new.tap do |grb_lin_expr|
      @terms.each do |term|
        grb_lin_expr.add_term(term.coeff, term.var.send(:grb_var))
      end
      grb_lin_expr.add_constant(@constant) unless @constant == 0
    end
  end
end
end
