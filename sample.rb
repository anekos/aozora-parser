# vim: set fileencoding=utf-8 :

require 'aozora-parser'

class Sample < AozoraParser::TreeWalker
  include AozoraParser

  def initialize ()
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
    p node.class

    case node
    when Tree::Document
    when Tree::Top
    when Tree::Bottom
    when Tree::Dots
    when Tree::Ruby
    when Tree::Bold
    when Tree::Yoko
    when Tree::HorizontalCenter
    when Tree::Line
    when Tree::Heading
      p node.level
    when Tree::Unicode
      p [node.char && node.char.code]
    when Tree::JIS
    when Tree::Note
    end

    # process inner node
    yield
  end

  def on_node_without_block (node, level)
    p node.class

    case node
    when Tree::Image
    when Tree::Text
    when Tree::LineBreak
    when Tree::SheetBreak, Tree::PageBreak, Tree::ParagraphBreak
    when Tree::Unknown
    else
      on_error('Not supported node', node)
    end
  end

  def on_image (source)
  end

  def on_end
    puts('おわり')
  end
end


source_filepath = ARGV.first

tree = AozoraParser::Parser.parse_file(source_filepath)
sample = Sample.new
sample.start(tree)
