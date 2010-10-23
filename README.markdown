Schema Transformer
=======

Summary
-------
This gem provides a way is alter database schemas on large tables with little downtime.  You run 2 commands to ultimately alter the database.  

First, you generate the schema transform definitions and commands to be ran later on production.  You will check these files into the rails project.

Second, you run 2 commands on production.

The first command will create a 'temporary' table with the altered schema and incrementally copy the data over until it is close to synced.  You can run this command as many times as you want as it want - it work hurt.  This first command is slow as it takes a while to copy the data over, especially if you have a really large tables that are several GBs in size.

The second command will do a switheroo with with 'temporarily' new table and the current table.  It will then remove the obsoleted table with the old schema structure.  Because it is doing a rename (which can screw up replication on a heavily traffik site), this second command should be ran with maintenance page up.  This second command is fast because it doe a final incremental sync and quickly switches the new table into place.

Install
-------

<pre>
gem install --no-ri --no-rdoc schema_transformer # sudo if you need to
</pre>

Usage
-------

Generate the schema transform definitions:

tung $ schema_transformer generate
What is the name of the table you want to alter?
> users
What is the modification to the table?
Examples 1: 
  ADD COLUMN teaser_lock tinyint(1) DEFAULT '0'
Examples 2: 
  ADD INDEX slide_id (slide_id)
Examples 3: 
  ADD COLUMN teaser_lock tinyint(1) DEFAULT '0', DROP COLUMN name
> ADD COLUMN teaser_lock tinyint(1) DEFAULT '0'
*** Thanks ***
schema transform definitions generated and have been saved to: config/schema_transformations/users.json
Next you need to run 2 commands to alter the database.  As explained in the README, the first can be ran with the site still up.  The second command should be done with a maintenance page up.
Here are the 2 commands:
$ schema_transformer sync users  # can be ran over and over, it will just keep syncing the data
$ schema_transformer switch users # should be done with a maintenance page up
*** Thank you ***
tung $ 

FAQ
-------

Q: What table alteration are supported?  
A: I've only tested with adding columns and removing columns.

Q: Can I add and drop multiple columns and indexes at the same time?
A: Yes.

Cautionary Notes
-------
For speed reasons he final sync is done by using the updated_at timestamp if available and syncing 
the data last updated since the last day.  Data before that will not get synced in the final sync.
So, having an updated_at timestamp and using it on the original table is very important.

For tables that do not have updated_at timestamps.  I need to still limit the size of the final update
so I'm limiting it to the last 100_000 records.  Not much at all, so it is very important to have that 
updated_at timestamp.
