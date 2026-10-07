require "spec_helper"

module Scenic
  module Adapters
    describe Postgres::Views, :db do
      it "returns scenic view objects for plain old views" do
        connection = ActiveRecord::Base.connection
        connection.execute <<-SQL
          CREATE VIEW children AS SELECT text 'Elliot' AS name
        SQL

        views = Postgres::Views.new(connection).all
        first = views.first

        expect(views.size).to eq 1
        expect(first.name).to eq "children"
        expect(first.materialized).to be false
        expect(first.definition).to eq "SELECT 'Elliot'::text AS name;"
      end

      it "returns scenic view objects for materialized views" do
        connection = ActiveRecord::Base.connection
        connection.execute <<-SQL
          CREATE MATERIALIZED VIEW children AS SELECT text 'Owen' AS name
        SQL

        views = Postgres::Views.new(connection).all
        first = views.first

        expect(views.size).to eq 1
        expect(first.name).to eq "children"
        expect(first.materialized).to be true
        expect(first.definition).to eq "SELECT 'Owen'::text AS name;"
      end

      it "returns definitions that survive recreating the view from them" do
        connection = ActiveRecord::Base.connection
        connection.execute "CREATE TABLE fruits (name varchar)"
        connection.execute <<-SQL
          CREATE VIEW sweet_fruits AS
          SELECT name FROM fruits WHERE name IN ('apple', 'pear')
        SQL

        definition = Postgres::Views.new(connection).all.first.definition
        connection.execute "DROP VIEW sweet_fruits"
        connection.execute "CREATE VIEW sweet_fruits AS #{definition}"

        expect(Postgres::Views.new(connection).all.first.definition)
          .to eq definition
      end
    end
  end
end
