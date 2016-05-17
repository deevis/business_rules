# :model_events=>
#   {"PyrCommunity"=>
#     {"Blog"=>
#       {:context=>
#         {"id"=>{:type=>:integer},
#          "title"=>{:type=>:string},
#          "author_id"=>{:type=>:integer},
#          "disqus_shortname"=>{:type=>:string},
#          "background_tile"=>{:type=>:boolean},
#          "background_blur"=>{:type=>:integer},
#          "footer"=>{:type=>:text},
#          "description"=>{:type=>:text},
#          "twitter"=>{:type=>:string},
#          "google_analytics"=>{:type=>:string},
#          "background_uid"=>{:type=>:string},
#          "logo_uid"=>{:type=>:string},
#          "created_at"=>{:type=>:datetime},
#          "updated_at"=>{:type=>:datetime}},
#        :actions=>[:create, :update, :delete]}
#       }
#     },
#    "PyrCore"=>
#     {"Lead"=>
#       {:context=>
#         {"id"=>{:type=>:integer},
#          "first_name"=>{:type=>:string},
#          "last_name"=>{:type=>:string},
#          "email"=>{:type=>:string},
#          "phone"=>{:type=>:string},
#          "lead_group"=>{:type=>:string},
#          "comments"=>{:type=>:text},
#          "user_id"=>{:type=>:integer},
#          "created_at"=>{:type=>:datetime},
#          "updated_at"=>{:type=>:datetime}},
#        :actions=>[:create, :update, :delete]}}}}



module Rules::EventsHelper


	def render_tree(events_tree)
		stack = []
		content_tag :div, id: "events_tree" do
			body = ""
			events_tree.each do |event_type, sub_events|
				body += _render_and_recurse(event_type, sub_events, stack) + "\n"
			end
			body.html_safe
		end
	end


	def _render_and_recurse(key,children,stack)
		return "" if key.blank?	# escape - don't render context variables
		body = ""
		if key == :actions				# render each action as a leaf
			children.each do |action|
				body += _render_action_leaf(action, stack)
			end
		elsif key == :context
			body = content_tag :div, class: "collapse-group", style:"block:inline;margin-left:30px;padding:5px;" do
				content_tag :div, id:"#{stack.join('_')}_context", class: "collapse", style: "block:inline;padding:5px;min-height:30px;" do
					context = children.collect{|k,v| "<b>#{k}</b> (<i>#{v}</i>)"}.join("<br/>")
					inner_body = "<a class='btn btn-mini' data-toggle='collapse' data-target='##{stack.join('_')}_context'>context</a>".html_safe
					inner_body += "<div class='collapse-group'>#{context}</div>".html_safe
					inner_body += "<div style='clear:both;'></div>".html_safe
				end
			end
		else
			stack.push key
			body += content_tag :div, class: "collapse-group", style: "margin-left:30px;position:relative;" do
						content_tag :div, id:"#{stack.join('_')}", class: "collapse", style: "padding:5px;min-height:30px;" do
							inner_body = "<a class='btn btn-mini' data-toggle='collapse' data-target='##{stack.join('_')}'>+</a><span style='font-weight:bold;'>#{key.to_s.titleize}</span>"
							children.each do |child_key, grandkids|
								#inner_body += "&nbsp;" * stack.size
								inner_body += _render_and_recurse(child_key, grandkids, stack) + "\n"
							end
							inner_body.html_safe
						end
					end
			stack.pop
		end
		body.html_safe
	end

	def _render_action_leaf(action_name, stack)
		name = "#{stack.join('::')}_#{action_name}"
		content_tag :div, id: name, style:"margin-left:30px;padding:5px;" do
			content_tag :input, name: name, type: "checkbox" do
				"<span style='margin-left:10px;'>#{action_name.to_s}</span>".html_safe
			end
		end
	end
end
