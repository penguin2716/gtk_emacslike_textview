#-*- coding: utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), "emacslike_textview"))

Plugin.create :gtk_emacslike_textview do
  on_before_postbox_post do |text|
    Gtk::EmacsLikeTextView.pushGlobalStack(text) 
  end

  command(:expand_snippet,
          name: 'snippetを展開',
          condition: lambda{ |opt| true },
          visible: true,
          role: :postbox) do |opt|
    Plugin.create(:gtk).widgetof(opt.widget).widget_post.expand_snippet
  end

  command(:update_language,
          name: 'ハイライトする言語を変更',
          condition: lambda{ |opt| true },
          visible: true,
          role: :postbox) do |opt|
    Plugin.create(:gtk).widgetof(opt.widget).widget_post.update_language_post
  end

end

