require './phomo2sce.rb'

class String
  # colorization
  def colorize(color_code)
    "\e[#{color_code}m#{self}\e[0m"
  end

  def red
    colorize(31)
  end

  def green
    colorize(32)
  end

  def yellow
    colorize(33)
  end

  def blue
    colorize(34)
  end

  def pink
    colorize(35)
  end

  def light_blue
    colorize(36)
  end
end

class Phomo2SceTest
  def initialize(filename_test, filename_target)
    text=File.open(filename_test).read
    @ruleset = text.gsub(/\r\n?/, "\n").split("\n") # split by line
    tt=File.open(filename_target).read
    @target = tt.gsub(/\r\n?/, "\n").split("\n") # split by line
  end

  def run_test
    rs_count = @ruleset.count
    i_good = 0
    i_bad = 0
    @ruleset.each_with_index do |rule, ix|
      puts "[#{(ix+1).to_s.light_blue}] Converting rule: #{rule}"
      r = PhomoRule.new(rule).to_sce
      puts "Output: #{r}"
      if @target[ix] == r
        puts "No problems!".green
        i_good += 1
      else
        puts "No match.".red
        puts "Goal was: #{@target[ix]}"
        i_bad += 1
      end
      puts ''
    end
    puts "Test finished (tested #{rs_count} rules)"
    puts "#{i_good} matches (#{((i_good/rs_count)*100).round}%)".green if i_good > 0
    puts "#{i_bad} mismatches (#{((i_bad/rs_count)*100).round}%)".red if i_bad > 0
  end
end

def run
  test = Phomo2SceTest.new(ARGV[0], ARGV[1])
  test.run_test
end
run if __FILE__==$0
