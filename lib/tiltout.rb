# encoding: utf-8
# --
# The MIT License (MIT)
#
# Copyright (C) 2012 Gitorious AS
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#++
require "tilt"
require "tiltout/version"
require "tiltout/partials"

class Tiltout
  attr_reader :paths

  def initialize(template_root, opt = {})
    @paths = Array(template_root)
    @cache = {} if !opt.key?(:cache) || opt[:cache]
    @layout = opt[:layout]
    @default_type = opt[:default_type] || "erb"
    @context_class = Class.new
    helper(opt[:helpers])
  end

  def helper(helpers)
    return if helpers.nil?
    helpers = [helpers] unless helpers.is_a?(Array)
    helpers.each { |h| @context_class.send(:include, helper_module(h)) }
  end

  def render(template, locals = {}, options = {})
    context = @context_class.new
    context.renderer = self if context.respond_to?(:renderer=)
    content = render_in_context(context, template, locals)
    layout_tpl = options.key?(:layout) ? options[:layout] : @layout

    if !layout_tpl.nil?
      content = render_in_context(context, layout_tpl, locals) { content }
    end

    content
  end

  def render_in_context(context, template, locals, &block)
    load(template).render(context, locals, &block)
  end

  private
  def load(name)
    file_name = find_file(name)
    return @cache[file_name] if cached?(file_name)
    template = Tilt.new(file_name)
    cache(file_name, template)
    template
  end

  def find_file(name)
    return name[:file] if name.is_a?(Hash)
    paths.each do |path|
      full_name = File.join(path, name.to_s)
      return full_name if cached?(full_name) || File.exists?(full_name)
      full_name = File.join(path, "#{name}.#{@default_type}")
      return full_name if cached?(full_name) || File.exists?(full_name)
    end
    nil
  end

  def cache(name, template)
    @cache[name] = template if @cache
  end

  def cached?(name)
    @cache && !!@cache[name]
  end

  def helper_module(mod)
    return mod if mod.is_a?(Module)
    mod.keys.inject(Module.new) do |helper, attr|
      helper.send(:define_method, attr) { mod[attr] }
      helper
    end
  end
end
