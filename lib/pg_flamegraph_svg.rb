require 'json'
require 'securerandom'

class PostgreSQLFlameGraphSVG
  def initialize(explain_json, width = 1200, height = 600)
    @explain_data = JSON.parse(explain_json)
    @width = width
    @height = height
    @font_size = 12
    @min_width = 1
    @colors = [
      '#e74c3c', '#3498db', '#2ecc71', '#f39c12', '#9b59b6',
      '#1abc9c', '#e67e22', '#95a5a6', '#34495e', '#e91e63'
    ]
  end

  def generate_svg
    plan = @explain_data[0]['Plan']

    # Calculate the layout
    flamegraph_data = build_flamegraph_data(plan)

    # Generate SVG
    generate_svg_content(flamegraph_data)
  end

  private

  def build_flamegraph_data(plan, depth = 0, start_time = 0)
    node_name = format_node_name(plan)
    actual_time = plan['Actual Total Time'] || 0

    # Create the current node
    current_node = {
      name: node_name,
      time: actual_time,
      depth: depth,
      start: start_time,
      children: []
    }

    # Process children
    if plan['Plans']
      child_start = start_time
      plan['Plans'].each do |child_plan|
        child_node = build_flamegraph_data(child_plan, depth + 1, child_start)
        current_node[:children] << child_node
        child_start += child_node[:time]
      end
    end

    current_node
  end

  def format_node_name(node)
    node_type = node['Node Type']

    # Add relevant details
    details = []

    if node['Relation Name']
      details << node['Relation Name']
    end

    if node['Index Name']
      details << "idx:#{node['Index Name']}"
    end

    if node['Join Type']
      details << node['Join Type']
    end

    # Build the final name
    name = node_type
    unless details.empty?
      name += " (#{details.join(', ')})"
    end

    # Add timing info
    if node['Actual Total Time']
      name += " [#{node['Actual Total Time'].round(2)}ms]"
    end

    name
  end

  def generate_svg_content(flamegraph_data)
    max_depth = calculate_max_depth(flamegraph_data)
    total_time = flamegraph_data[:time]

    svg_height = (max_depth + 1) * (@font_size + 4) + 40

    svg = <<~SVG
      <?xml version="1.0" encoding="UTF-8"?>
      <svg width="#{@width}" height="#{svg_height}" xmlns="http://www.w3.org/2000/svg">
        <style>
          .frame { stroke: white; stroke-width: 1; cursor: pointer; }
          .frame:hover { stroke: black; stroke-width: 2; }
          .frame-text { font-family: monospace; font-size: #{@font_size}px; fill: white; pointer-events: none; }
          .title { font-family: Arial; font-size: 16px; font-weight: bold; fill: #333; }
          .subtitle { font-family: Arial; font-size: 12px; fill: #666; }
        </style>

        <!-- Title -->
        <text x="#{@width/2}" y="20" class="title" text-anchor="middle">PostgreSQL Query Execution Plan Flamegraph</text>
        <text x="#{@width/2}" y="35" class="subtitle" text-anchor="middle">Total Execution Time: #{total_time.round(2)}ms</text>

        <!-- Flamegraph -->
        <g transform="translate(0, 45)">
    SVG

    # Generate rectangles recursively
    svg += generate_rectangles(flamegraph_data, total_time, 0)

    svg += <<~SVG
        </g>
      </svg>
    SVG

    svg
  end

  def generate_rectangles(node, total_time, y_offset)
    return "" if node[:time] <= 0

    # Calculate dimensions
    width_ratio = node[:time] / total_time
    rect_width = [@width * width_ratio, @min_width].max
    rect_height = @font_size + 4

    x_position = (node[:start] / total_time) * @width
    y_position = y_offset

    # Choose color based on node type
    color = get_node_color(node[:name])

    # Generate rectangle and text
    svg = <<~SVG
      <rect class="frame"
            x="#{x_position}"
            y="#{y_position}"
            width="#{rect_width}"
            height="#{rect_height}"
            fill="#{color}">
        <title>#{escape_xml(node[:name])}
Time: #{node[:time].round(2)}ms
Percentage: #{((node[:time] / total_time) * 100).round(1)}%</title>
      </rect>
    SVG

    # Add text if rectangle is wide enough
    if rect_width > 50
      text_x = x_position + 4
      text_y = y_position + @font_size + 1

      # Truncate text if necessary
      display_text = truncate_text(node[:name], rect_width - 8)

      svg += <<~SVG
        <text class="frame-text" x="#{text_x}" y="#{text_y}">#{escape_xml(display_text)}</text>
      SVG
    end

    # Generate children
    child_y = y_position + rect_height + 2
    node[:children].each do |child|
      svg += generate_rectangles(child, total_time, child_y)
    end

    svg
  end

  def calculate_max_depth(node, current_depth = 0)
    max_child_depth = current_depth

    node[:children].each do |child|
      child_depth = calculate_max_depth(child, current_depth + 1)
      max_child_depth = [max_child_depth, child_depth].max
    end

    max_child_depth
  end

  def get_node_color(node_name)
    # Color code by operation type
    case node_name
    when /Seq Scan/
      '#e74c3c'  # Red - potentially slow
    when /Index.*Scan/
      '#2ecc71'  # Green - good
    when /Hash Join|Nested Loop|Merge Join/
      '#3498db'  # Blue - joins
    when /Sort|Aggregate/
      '#f39c12'  # Orange - processing
    when /Result/
      '#95a5a6'  # Gray - simple
    else
      # Cycle through colors based on hash
      @colors[node_name.hash.abs % @colors.length]
    end
  end

  def truncate_text(text, max_width)
    # Rough estimate: 1 character ≈ 7 pixels in monospace
    max_chars = (max_width / 7).to_i

    if text.length <= max_chars
      text
    else
      text[0, max_chars - 3] + "..."
    end
  end

  def escape_xml(text)
    text.gsub('&', '&amp;')
        .gsub('<', '&lt;')
        .gsub('>', '&gt;')
        .gsub('"', '&quot;')
        .gsub("'", '&#39;')
  end
end