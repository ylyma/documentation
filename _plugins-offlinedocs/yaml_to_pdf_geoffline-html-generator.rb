require 'yaml'
require 'kramdown'
require 'nokogiri'
require 'uri'
require 'net/http'
require 'fileutils'

class OfflineHtmlGenerator
  def initialize(yaml_file, base_dir)
    @base_dir = base_dir
    @yaml_data = YAML.load_file(yaml_file)
    @html_template = create_template
  end

  def fetch_content(url)
    # read local file content
    full_path = File.join(@base_dir, url)
    
    if File.exist?(full_path)
      File.read(full_path)
    else
      puts "File not found: #{full_path}"
      "<p>Content not found for: #{url}</p>"
    end
  rescue => e
    # display error for wrong path 
    puts "Error fetching content for #{url}: #{e.message}"
    "<p>Error loading content for: #{url}</p>"
  end

  def process_content(content, url)
    # remove formatter from the start of files
    content = content.sub(/\A---(.|\n)*?---\n/, '')
    
    # convert based on file type 
    if url.end_with?('.md')
      Kramdown::Document.new(content).to_html
    elsif url.end_with?('.html')
      doc = Nokogiri::HTML(content)
      body = doc.at_css('body')
      body ? body.inner_html : content
    else
      # detect md by heading format
      if content.match?(/^#\s/)
        Kramdown::Document.new(content).to_html
      else
        content
      end
    end
  end

  def generate_sidebar
    @yaml_data['docs'].map do |section|
      section_html = ['<div class="section">']
      section_html << "<div class=\"section-title\">#{section['title']}</div>"
      
      section['documents'].each do |doc|
        next if doc['sidebar_exclude']
        
        url = doc['url']
        # create html ids from the urls for navigation
        anchor = url.sub(%r{^/en/}, '').gsub('/', '-').gsub(/^\.|-$/, '')
        section_html << "<a href=\"##{anchor}\" class=\"nav-link\">#{doc['page']}</a>"
      end
      
      section_html << '</div>'
      section_html.join("\n")
    end.join("\n")
  end

  def generate_content
    @yaml_data['docs'].flat_map do |section|
      section['documents'].map do |doc|
        url = doc['url']
        # should be offline, so no http
        next if url.start_with?('http')
        
        # create html ids from urls for navigation
        anchor = url.sub(%r{^/en/}, '').gsub('/', '-').gsub(/^\.|-$/, '')
        content = fetch_content(url)
        processed_content = process_content(content, url)
        
        <<~HTML
          <div id="#{anchor}" class="content-section">
            <h1>#{doc['page']}</h1>
            #{processed_content}
          </div>
        HTML
      end
    end.compact.join("\n")
  end

  def generate_html(output_file)
    sidebar_content = generate_sidebar
    main_content = generate_content
    
    complete_html = @html_template % {
      sidebar_content: sidebar_content,
      main_content: main_content
    }
    
    File.write(output_file, complete_html)
    puts "Documentation generated successfully: #{output_file}"
  end

  def create_template
    # basic formatting for the html page
    <<~HTML
      <!DOCTYPE html>
      <html lang="en">
      <head>
          <meta charset="UTF-8">
          <meta name="viewport" content="width=device-width, initial-scale=1.0">
          <title>Documentation</title>
          <style>
              :root {
                  --sidebar-width: 300px;
                  --primary-color: #333;
                  --bg-color: #ffffff;
                  --sidebar-bg: #f5f5f5;
              }
              
              body {
                  margin: 0;
                  padding: 0;
                  font-family: system-ui, sans-serif;
                  line-height: 1.6;
                  color: var(--primary-color);
                  background: var(--bg-color);
              }
              
              .container {
                  display: flex;
                  min-height: 100vh;
              }
              
              .sidebar {
                  width: var(--sidebar-width);
                  position: fixed;
                  left: 0;
                  top: 0;
                  height: 100vh;
                  overflow-y: auto;
                  padding: 20px;
                  box-sizing: border-box;
                  background: var(--sidebar-bg);
                  border-right: 1px solid #ddd;
              }
              
              .main-content {
                  margin-left: var(--sidebar-width);
                  padding: 40px;
                  flex: 1;
                  max-width: 900px;
              }
              
              .section {
                  margin-bottom: 20px;
              }
              
              .section-title {
                  font-weight: bold;
                  font-size: 1.2em;
                  margin: 15px 0 10px 0;
                  color: #2c3e50;
              }
              
              .nav-link {
                  display: block;
                  padding: 5px 0;
                  color: #486581;
                  text-decoration: none;
                  font-size: 0.95em;
              }
              
              .nav-link:hover {
                  color: #0366d6;
              }
              
              .content-section {
                  margin-bottom: 40px;
                  scroll-margin-top: 20px;
              }
              
              h1, h2, h3 {
                  color: #2c3e50;
              }
              
              code {
                  background: #f6f8fa;
                  padding: 2px 5px;
                  border-radius: 3px;
                  font-size: 0.9em;
              }
              
              pre {
                  background: #f6f8fa;
                  padding: 15px;
                  border-radius: 5px;
                  overflow-x: auto;
              }
              
              @media print {
                  .sidebar {
                      display: none;
                  }
                  .main-content {
                      margin-left: 0;
                  }
              }
              
              @media (max-width: 768px) {
                  .sidebar {
                      display: none;
                  }
                  .main-content {
                      margin-left: 0;
                  }
              }
          </style>
      </head>
      <body>
          <div class="container">
              <nav class="sidebar">
                  %{sidebar_content}
              </nav>
              <main class="main-content">
                  %{main_content}
              </main>
          </div>
      </body>
      </html>
    HTML
  end
end
