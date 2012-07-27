# vim: set fileencoding=utf-8 :

require 'aozora-parser'
require 'cgi'
require 'uri'

class HTMLGenerator < AozoraParser::TreeWalker
  include AozoraParser

  class Anchor < Struct.new(:id, :text)
  end

  def initialize (title)
    @title = title
    @anchor_number = 0
  end

  def start (tree)
    raw_print(<<-"EOH")
<?xml version="1.0" encoding="Shift_JIS"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="ja">
<head>
  <meta http-equiv="Content-Type" content="text/html; charset=Shift_JIS" />
</head>
<style>
  body {
    margin-right: 10%;
    margin-left: 10%;
  }
</style>
<title>#{h(@title)}</title>
<script language="javascript">
  window.addEventListener(
    'load',
    function () {
      var index = document.querySelector('#index');
      var indexList = index.querySelector('ul');
      var as = document.querySelectorAll('.anchor');
      for (var i = 0; i < as.length; i++) {
        var e = document.createElement('li');
        var a = document.createElement('a');
        a.textContent = as[i].textContent;
        a.href = "#" + as[i].id;
        e.appendChild(a);
        indexList.appendChild(e);
      }

      var toggleIndex = document.querySelector('#toggle-index');
      toggleIndex.addEventListener(
        'click',
        function () {
          index.style.display = /none/.test(index.style.display) ? 'block' : 'none';
        },
        true
      );
    },
    true
  );
</script>
</body>

<h1 id="toggle-index"><a href="#">#{'目次'.encode(Encoding::CP932)}</a></h1>
<div id="index" style="display: none">
  <ul />
</div>
<hr />
    EOH

    super tree

    raw_print(<<-EOH)
</body>
</html>
    EOH
  end

  private

  def on_error (msg, node = nil)
    msg += ": #{node.class.display_name} at L#{node.token ? node.token.line : '?'}" if node
    raise msg
  end

  def on_node (node, level, &block)
    if block
      on_node_with_block(node, level, &block)
    else
      on_node_without_block(node, level)
    end
  end

  def on_node_with_block (node, level)

    # NOTE node.text が textContent 的なものになる

    case node
    when Tree::Document
    when Tree::Top
      tag(:p, :style => "margin-left: #{node.level}em") { yield }
      return
    when Tree::Bottom
    when Tree::Dots
    when Tree::Ruby
      # <ruby><rb>塵埃</rb><rp>（</rp><rt>ほこり</rt><rp>）</rp></ruby>
      if node.ruby
        tag(:ruby) do
          tag(:rb) { yield }
          tag(:rp) { print(e("（")) }
          tag(:rt) { print(node.ruby) }
          tag(:rp) { print(e("）")) }
        end
        return
      end
    when Tree::Bold
      tag(:span, :style => 'font-weight: bold') { yield }
      return
    when Tree::Yoko
    when Tree::HorizontalCenter
    when Tree::Line
    when Tree::Heading
      em =
        case node.level.encode(Encoding::UTF_8)
        when /大/
          4.0
        when /中/
          2.0
        when /小/
          1.5
        else
          2.0
        end
      tag(:span, :id => new_anchor,
                 :class => 'anchor',
                 :style => "font-weight: bold; font-size: #{em}em") { yield }
      return
    when Tree::Unicode
    when Tree::JIS
    when Tree::Note
    end

    # 内側のノードを処理する
    yield
  end

  def on_node_without_block (node, level)
    case node
    when Tree::Image
      tag(:img, :src => "file://" + URI.encode(node.source))
    when Tree::Text
      tag(:span) { print(node.text) }
    when Tree::LineBreak
      tag(:br)
      puts('')
    when Tree::SheetBreak, Tree::PageBreak, Tree::ParagraphBreak
    when Tree::Unknown
    else
      on_error('Not supported node', node)
    end
  end

  def on_end
    puts('おわり')
  end

  def tag (name, attrs = {}, &block)
    joined_as = attrs.map {|k, v| "#{k}='#{h(v)}'" } .join(' ')
    head = "<#{name} #{joined_as}"
    if block
      raw_print(head + ">")
     block.call
      raw_print("</#{name}>")
    else
      raw_print(head + "/>")
    end
  end

  def print (s)
    raw_print(h(s))
  end

  def puts (s)
    raw_puts(h(s))
  end

  def raw_print (s)
    STDOUT.print(s)
  end

  def raw_puts (s)
    STDOUT.puts(s)
  end

  def e (s)
    s.encode(Encoding::CP932)
  end

  def h (s)
    CGI.escape_html(s)
  end

  def new_anchor
    @anchor_number += 1
    "anchor_#{@anchor_number}"
  end
end


if __FILE__ == $0
  then
  source_filepath = ARGV.first

  tree = AozoraParser::Parser.parse_file(source_filepath)
  sample = HTMLGenerator.new(File.basename(source_filepath).encode(Encoding::CP932))
  sample.start(tree)
end
