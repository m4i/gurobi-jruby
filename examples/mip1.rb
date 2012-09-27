# @see http://www.gurobi.com/documentation/5.0/quick-start-guide/node12

$LOAD_PATH.unshift(
  File.expand_path('../../lib', __FILE__),
  File.join(ENV['GUROBI_HOME'], 'lib')
)

require 'java'
require 'gurobi'

java_import 'gurobi.GRBException'

begin
  # Create a new model
  model = Gurobi::Model.new

  # Create variables
  x = model.add_binary_var(name: :x)
  y = model.add_binary_var(name: :y)
  z = model.add_binary_var(name: :z)

  # Set objective
  model.set_objective(x + y + 2 * z, :maximize)

  # Add constraint: x + 2 y + 3 z <= 4
  model.add_constr(x + 2 * y + 3 * z <= 4, :c0)

  # Add constraint: x + y >= 1
  model.add_constr(x + y >= 1, :c1)

  model.env = Gurobi::Env.new
  begin
    model.optimize
  ensure
    model.env.dispose
  end

  model.vars.each do |var|
    puts "#{var.name}: #{var.x}"
  end

  puts "Obj: #{model.obj_val}"

rescue GRBException => e
  puts "Error code: #{e.error_code}. #{e.message}"
end
