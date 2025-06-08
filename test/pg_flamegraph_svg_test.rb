require_relative 'test_helper'
require_relative '../lib/pg_flamegraph_svg'

class PostgreSQLFlameGraphSVGTest < Minitest::Test
  def setup
    @simple_explain_json = [{
      "Plan" => {
        "Node Type" => "Seq Scan",
        "Relation Name" => "users",
        "Actual Total Time" => 45.23
      }
    }].to_json

    @complex_explain_json = [{
      "Plan" => {
        "Node Type" => "Hash Join",
        "Join Type" => "Inner",
        "Actual Total Time" => 123.45,
        "Plans" => [
          {
            "Node Type" => "Index Scan",
            "Relation Name" => "users",
            "Index Name" => "users_id_idx",
            "Actual Total Time" => 56.78
          },
          {
            "Node Type" => "Seq Scan",
            "Relation Name" => "orders",
            "Actual Total Time" => 67.89
          }
        ]
      }
    }].to_json

    @zero_time_explain_json = [{
      "Plan" => {
        "Node Type" => "Result",
        "Actual Total Time" => 0
      }
    }].to_json
  end

  def test_initialize_with_defaults
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)
    assert_equal 1200, generator.instance_variable_get(:@width)
    assert_equal 600, generator.instance_variable_get(:@height)
    assert_equal 20, generator.instance_variable_get(:@font_size)
    assert_equal 1, generator.instance_variable_get(:@min_width)
  end

  def test_initialize_with_custom_dimensions
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json, 800, 400)
    assert_equal 800, generator.instance_variable_get(:@width)
    assert_equal 400, generator.instance_variable_get(:@height)
  end

  def test_generate_svg_simple
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)
    svg = generator.generate_svg

    assert_includes svg, '<?xml version="1.0" encoding="UTF-8"?>'
    assert_includes svg, 'PostgreSQL Query Execution Plan Flamegraph'
    assert_includes svg, 'Total Execution Time: 45.23ms'
    assert_includes svg, 'Seq Scan'
    assert_includes svg, 'users'
  end

  def test_generate_svg_complex_with_children
    generator = PostgreSQLFlameGraphSVG.new(@complex_explain_json)
    svg = generator.generate_svg

    assert_includes svg, 'Hash Join'
    assert_includes svg, 'Inner'
    assert_includes svg, 'Index Scan'
    assert_includes svg, 'users_id_idx'
    assert_includes svg, 'Seq Scan'
    assert_includes svg, 'orders'
  end

  def test_build_flamegraph_data_simple
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)
    plan = JSON.parse(@simple_explain_json)[0]['Plan']

    data = generator.send(:build_flamegraph_data, plan)

    assert_equal 0, data[:depth]
    assert_equal 0, data[:start]
    assert_equal 45.23, data[:time]
    assert_includes data[:name], 'Seq Scan'
    assert_includes data[:name], 'users'
    assert_includes data[:name], '[45.23ms]'
    assert_equal [], data[:children]
  end

  def test_build_flamegraph_data_with_children
    generator = PostgreSQLFlameGraphSVG.new(@complex_explain_json)
    plan = JSON.parse(@complex_explain_json)[0]['Plan']

    data = generator.send(:build_flamegraph_data, plan)

    assert_equal 0, data[:depth]
    assert_equal 123.45, data[:time]
    assert_equal 2, data[:children].length

    # Test first child
    first_child = data[:children][0]
    assert_equal 1, first_child[:depth]
    assert_equal 0, first_child[:start]
    assert_equal 56.78, first_child[:time]
    assert_includes first_child[:name], 'Index Scan'
    assert_includes first_child[:name], 'users_id_idx'

    # Test second child
    second_child = data[:children][1]
    assert_equal 1, second_child[:depth]
    assert_equal 56.78, second_child[:start] # Started after first child
    assert_equal 67.89, second_child[:time]
  end

  def test_format_node_name_with_all_details
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    node = {
      'Node Type' => 'Hash Join',
      'Relation Name' => 'users',
      'Index Name' => 'users_idx',
      'Join Type' => 'Inner',
      'Actual Total Time' => 123.45
    }

    name = generator.send(:format_node_name, node)

    assert_includes name, 'Hash Join'
    assert_includes name, 'users'
    assert_includes name, 'idx:users_idx'
    assert_includes name, 'Inner'
    assert_includes name, '[123.45ms]'
  end

  def test_format_node_name_minimal
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    node = {
      'Node Type' => 'Result'
    }

    name = generator.send(:format_node_name, node)

    assert_equal 'Result', name
  end

  def test_format_node_name_without_timing
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    node = {
      'Node Type' => 'Seq Scan',
      'Relation Name' => 'table1'
    }

    name = generator.send(:format_node_name, node)

    assert_equal 'Seq Scan (table1)', name
  end

  def test_generate_rectangles_with_zero_time
    generator = PostgreSQLFlameGraphSVG.new(@zero_time_explain_json)

    node = { name: 'Test', time: 0, start: 0, children: [] }
    result = generator.send(:generate_rectangles, node, 100, 0)

    assert_equal "", result
  end

  def test_generate_rectangles_narrow_width
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    node = { name: 'Short', time: 1, start: 0, children: [] }
    result = generator.send(:generate_rectangles, node, 100, 0)

    # Should generate rectangle but no text (width < 50)
    assert_includes result, '<rect'
    refute_includes result, '<text'
  end

    def test_generate_rectangles_wide_width
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    # Use a large time relative to total to ensure width > 50
    node = { name: 'Wide Operation Name', time: 80, start: 0, children: [] }
    result = generator.send(:generate_rectangles, node, 80, 0)  # total_time = time for 100% width

    # Should generate both rectangle and text (width >= 50)
    assert_includes result, '<rect'
    assert_includes result, '<text'
    assert_includes result, 'Wide Operation Name'
  end

  def test_generate_rectangles_with_children
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    parent = {
      name: 'Parent',
      time: 100,
      start: 0,
      children: [
        { name: 'Child1', time: 40, start: 0, children: [] },
        { name: 'Child2', time: 60, start: 40, children: [] }
      ]
    }

    result = generator.send(:generate_rectangles, parent, 100, 0)

    # Should contain parent and children
    assert_includes result, 'Parent'
    assert_includes result, 'Child1'
    assert_includes result, 'Child2'
  end

  def test_calculate_max_depth_simple
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    node = { children: [] }
    depth = generator.send(:calculate_max_depth, node, 0)

    assert_equal 0, depth
  end

  def test_calculate_max_depth_nested
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    node = {
      children: [
        {
          children: [
            { children: [] }
          ]
        },
        { children: [] }
      ]
    }

    depth = generator.send(:calculate_max_depth, node, 0)

    assert_equal 2, depth
  end

  def test_get_node_color_seq_scan
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    color = generator.send(:get_node_color, 'Seq Scan')
    assert_equal '#e74c3c', color
  end

  def test_get_node_color_index_scan
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    color = generator.send(:get_node_color, 'Index Scan')
    assert_equal '#2ecc71', color

    color = generator.send(:get_node_color, 'Index Only Scan')
    assert_equal '#2ecc71', color
  end

  def test_get_node_color_joins
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    assert_equal '#3498db', generator.send(:get_node_color, 'Hash Join')
    assert_equal '#3498db', generator.send(:get_node_color, 'Nested Loop')
    assert_equal '#3498db', generator.send(:get_node_color, 'Merge Join')
  end

  def test_get_node_color_processing
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    assert_equal '#f39c12', generator.send(:get_node_color, 'Sort')
    assert_equal '#f39c12', generator.send(:get_node_color, 'Aggregate')
  end

  def test_get_node_color_result
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    color = generator.send(:get_node_color, 'Result')
    assert_equal '#95a5a6', color
  end

  def test_get_node_color_unknown
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    color = generator.send(:get_node_color, 'Unknown Operation')
    # Should return one of the colors from the array
    colors = generator.instance_variable_get(:@colors)
    assert_includes colors, color
  end

  def test_truncate_text_short
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    result = generator.send(:truncate_text, 'Short', 100)
    assert_equal 'Short', result
  end

  def test_truncate_text_long
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    long_text = 'This is a very long operation name that should be truncated'
    result = generator.send(:truncate_text, long_text, 50)

    assert result.length < long_text.length
    assert result.end_with?('...')
  end

  def test_escape_xml_all_characters
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    text = "Test & <tag> \"quoted\" 'single'"
    escaped = generator.send(:escape_xml, text)

    assert_equal "Test &amp; &lt;tag&gt; &quot;quoted&quot; &#39;single&#39;", escaped
  end

  def test_escape_xml_no_special_characters
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)

    text = "Normal text 123"
    escaped = generator.send(:escape_xml, text)

    assert_equal text, escaped
  end

  def test_generate_svg_content_structure
    generator = PostgreSQLFlameGraphSVG.new(@simple_explain_json)
    plan = JSON.parse(@simple_explain_json)[0]['Plan']
    flamegraph_data = generator.send(:build_flamegraph_data, plan)

    svg = generator.send(:generate_svg_content, flamegraph_data)

    assert_includes svg, '<?xml version="1.0" encoding="UTF-8"?>'
    assert_includes svg, '<svg width="1200"'
    assert_includes svg, 'xmlns="http://www.w3.org/2000/svg"'
    assert_includes svg, '<style>'
    assert_includes svg, '.frame {'
    assert_includes svg, 'PostgreSQL Query Execution Plan Flamegraph'
    assert_includes svg, 'Total Execution Time:'
    assert_includes svg, '</svg>'
  end

  def test_complex_nested_plan
    nested_json = [{
      "Plan" => {
        "Node Type" => "Aggregate",
        "Actual Total Time" => 200.0,
        "Plans" => [
          {
            "Node Type" => "Hash Join",
            "Join Type" => "Left",
            "Actual Total Time" => 180.0,
            "Plans" => [
              {
                "Node Type" => "Seq Scan",
                "Relation Name" => "table1",
                "Actual Total Time" => 80.0
              },
              {
                "Node Type" => "Hash",
                "Actual Total Time" => 100.0,
                "Plans" => [
                  {
                    "Node Type" => "Index Scan",
                    "Relation Name" => "table2",
                    "Index Name" => "table2_idx",
                    "Actual Total Time" => 90.0
                  }
                ]
              }
            ]
          }
        ]
      }
    }].to_json

    generator = PostgreSQLFlameGraphSVG.new(nested_json)
    svg = generator.generate_svg

    assert_includes svg, 'Aggregate'
    assert_includes svg, 'Hash Join'
    assert_includes svg, 'Left'
    assert_includes svg, 'Seq Scan'
    assert_includes svg, 'table1'
    assert_includes svg, 'Hash'
    assert_includes svg, 'Index Scan'
    assert_includes svg, 'table2'
    assert_includes svg, 'idx:table2_idx'
  end

  def test_plan_without_actual_total_time
    no_time_json = [{
      "Plan" => {
        "Node Type" => "Seq Scan",
        "Relation Name" => "users"
      }
    }].to_json

    generator = PostgreSQLFlameGraphSVG.new(no_time_json)
    plan = JSON.parse(no_time_json)[0]['Plan']

    data = generator.send(:build_flamegraph_data, plan)

    assert_equal 0, data[:time]
    refute_includes data[:name], 'ms]'
  end
end