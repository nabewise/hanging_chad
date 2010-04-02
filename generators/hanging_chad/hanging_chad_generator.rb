class HangingChadGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.directory 'app'
      m.directory 'app/models'
      m.file      'vote.rb'      , 'app/models/vote.rb'
      m.file      'vote_total.rb', 'app/models/vote_total.rb'
      
      m.directory 'db'
      m.directory 'db/migrate'
      m.migration_template 'create_hanging_chad_tables.rb', 'db/migrate', :migration_file_name => 'create_hanging_chad_tables.rb'
    end
  end
end
