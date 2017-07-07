require './phomo2sce.rb'
require 'pathname'

# CONSOLE COLOURS! :D
class String
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
  def initialize(filename_test, filename_target, literal=false)
    # quit if files don't exist
    return false unless check_path(filename_test)
    return false unless check_path(filename_target)
    # load file of rules to translate and test
    txt_test=File.open(filename_test).read
    @ruleset = txt_test.gsub(/\r\n?/, "\n").split("\n") # split by line
    # load file to check against
    txt_target=File.open(filename_target).read
    @target = txt_target.gsub(/\r\n?/, "\n").split("\n") # split by line

    run_test(literal)
  end

  def check_path(pathname)
    pn = Pathname.new(pathname)
    puts "error! no such file as: #{pathname}" unless (e = pn.exist?)
    e # return boolean whether path exists or not
  end

  def run_test(literal=false)
    rs_count = @ruleset.count # initialise some count vars
    i_good = 0
    i_bad = 0
    @ruleset.each_with_index do |rule, ix| # loop through rules
      puts "[#{(ix+1).to_s.light_blue}] Converting rule: #{rule}"
      r = Phomo2Sce.new(rule).to_sce(literal) # translate rule
      puts "Output: #{r}"
      if @target[ix] == r # if matches goal, all is good
        puts "No problems!".green
        i_good += 1
      else
        puts "No match.".red # doesn't match goal, all is not good
        puts "Goal was: #{@target[ix]}"
        i_bad += 1
      end
      puts ''
    end
    # output test results
    puts "Test finished (tested #{rs_count} rules)"
    puts "#{i_good} matches (#{((i_good/rs_count)*100).round}%)".green if i_good > 0
    puts "#{i_bad} mismatches (#{((i_bad/rs_count)*100).round}%)".red if i_bad > 0
  end
end

def run
  args = ARGV.join(' ')
  literal = !(args.gsub!(/(\s|\A)\-l(\s|\z)/, '').nil?)
  as = args.split(' ')
  unless as[0].nil? || as[1].nil?
    test = Phomo2SceTest.new(ARGV[0], ARGV[1], literal)
  else
    puts "phomo2sce test - test if translation of ruleset matches target"
    puts "syntax: ruby p2stest.rb <test_filename> <goal_filename> [-l]"
    puts "-l is an optional flag to translate to literal SCE (without stylisation)"
  end
end
run if __FILE__==$0
