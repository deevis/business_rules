class Rules::Handlers::CreateModel < Rules::Handlers::Base

  needs :type, :class_lookup

  @@x = 0;

  def _handle
    model_instance = model_class.new
    if model_instance.respond_to? :user=
      model_instance.user = owner
    end
    set_model_props model_instance
    @@x+=1
    puts "Saving instance #{model_instance.attributes}::#{@@x}"
    model_instance.save!
    puts "Created instance of #{model_instance.class}[#{model_instance.id}]::#{@@x}"
    return model_instance
  end

  # Subclassers add your mappings here
  def set_model_props(m)
    fields_to_set = action.context_mapping.keys.map{|k| k.split(":=>").first} - ["type"]
    fields_to_set.each do |f| 
      value = self.send f.to_sym
      m.send "#{f}=".to_sym, value
    end
  end

  def model_class
    return type unless type.blank?
    raise "Subclassers please implement model_class"
  end

end