module SchemaTransformer
  module Help
    def help(action)
      case action
      when :generate
        out =<<-HELP
*** Thanks ***
Schema transform definitions have been generated and saved to: 
  config/schema_transformations/#{self.table}.json
Next you need to run 2 commands to alter the database.  As explained in the README, the first 
can be ran with the site still up.  The second command should be done with a maintenance page up.

Here are the 2 commands you'll need to run later after checking in the #{self.table}.json file
into your version control system:
$ schema_transformer sync #{self.table}   # can be ran over and over, it will just keep syncing the data
$ schema_transformer switch #{self.table} # should be done with a maintenance page up, switches the tables
*** Thank you ***
HELP
      when :sync
        out =<<-TEXT
*** Thanks ***
There is now a #{self.temp_table} table with the new table schema and the data has been synced.
Please run the next command after you put a maintenance page up:
$ schema_transformer switch #{self.table}
TEXT
      when :switch
        out =<<-TEXT
*** Thanks ***
The final sync ran and the table #{self.table} has been updated with the new schema.  
Get rid of that maintenance page and re-enable your site.
Thank you.  Have a very nice day.
TEXT
      end
      puts out
    end
    
  end
end