# plugins/random_tag.rb
module Jekyll
  class RandomTag < Liquid::Tag
    def initialize(tag_name, min, max, tokens)
      super
      @min = min.to_i
      @max = max.to_i
    end

    def render(context)
      rand(@min..@max).to_s
    end
  end
end

Liquid::Template.register_tag('random', Jekyll::RandomTag)
