require 'helper'

class TestSymbolic < Test::Unit::TestCase

  should "obtain symbolic objects from expressions involving declared variables" do
    assert_equal Symbolic::Expression, symbolic{var :x; x*3}.class
    assert_equal Symbolic::Expression, symbolic{var :x; 3*x}.class
    assert_equal Symbolic::Expression, symbolic{var :x; x+7}.class
    assert_equal Symbolic::Expression, symbolic{var :x; sin(x)}.class
  end

  should "evaluate symbolic expressions correctly" do
    assert_equal 3.0, symbolic{var :x; self.x=1.5; eval(x*2)}
    assert_equal 3.0, symbolic{var :x; self.x=1.5; eval(2*x)}
    assert_equal -1.5, symbolic{var :x; self.x=1.5; eval(-x)}
    assert_in_delta 0.997494986604054, symbolic{var :x; self.x=1.5; eval(sin(x))}, 1E-10
    assert_in_delta -0.676873339089758, symbolic{var :x; self.x=1.5; eval(2*sin(x**3)-x/7)}, 1E-10
  end

  should "evaluate symbolic expressions correctly with hash parameters" do
    assert_equal 3.0, symbolic{var :x; eval(x*2, :x=>1.5)}
    assert_equal 3.0, symbolic{var :x; eval(2*x, :x=>1.5)}
  end

  should "evaluate partially expression with free variables" do
    assert_equal "(4.0 - (2.0 * (y ** 2)))", symbolic{var :x, :y; eval(x*2-x*y**2, :x=>2.0).to_s}
  end

  should "allow definition of functions" do
    assert_equal "sqr(7)", symbolic{fun(:sqr){|x| x*x}; sqr(7).to_s}
    assert_equal 49, symbolic{fun(:sqr){|x| x*x}; eval(sqr(7))}
  end

  should "detect variables used in expressions" do
    assert_equal [:x], symbolic{var :x, :y; (sin(x*3.5)+2-x).vars}
    assert_equal [:x,:y], symbolic{var :x, :y; (sin(x*3.5)+2-y).vars}
  end

end
