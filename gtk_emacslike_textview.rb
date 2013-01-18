#-*- coding: utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), "emacslike_textview"))

Plugin.create :gtk_emacslike_textview do
  UserConfig[:etv_default_background_color] ||= [0xffff, 0xffff, 0xffff]
  UserConfig[:etv_default_foreground_color] ||= [0x0000, 0x0000, 0x0000]
  UserConfig[:etv_alternate_background_color] ||= [0xffff, 0xbbbb, 0xbbbb]
  UserConfig[:etv_alternate_foreground_color] ||= [0x0000, 0x0000, 0x0000]
  UserConfig[:etv_change_background_color] ||= true

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

  settings "EmacsLikePosbox" do
    settings "色の設定" do
      color("デフォルトの背景色", :etv_default_background_color)
      color("デフォルトの文字色", :etv_default_foreground_color)
      boolean("140文字数超過時に色を変更する", :etv_change_background_color)
      color("文字数超過時の背景色", :etv_alternate_background_color)
      color("文字数超過時の文字色", :etv_alternate_foreground_color)
    end
  end

end

