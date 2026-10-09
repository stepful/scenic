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

      it "returns definitions of materialized views that survive recreating the view from them" do
        connection = ActiveRecord::Base.connection
        connection.execute "CREATE TABLE fruits (name varchar)"
        connection.execute <<-SQL
          CREATE MATERIALIZED VIEW sweet_fruits AS
          SELECT name FROM fruits WHERE name IN ('apple', 'pear')
        SQL

        view = Postgres::Views.new(connection).all.first
        connection.execute "DROP MATERIALIZED VIEW sweet_fruits"
        connection.execute "CREATE MATERIALIZED VIEW sweet_fruits AS #{view.definition}"

        reloaded = Postgres::Views.new(connection).all.first
        expect(reloaded.materialized).to be true
        expect(reloaded.definition).to eq view.definition
      end

      it "keeps the original definition when it cannot be recreated" do
        connection = ActiveRecord::Base.connection
        connection.execute "CREATE TABLE fruits (name varchar)"
        connection.execute <<-SQL
          CREATE VIEW sweet_fruits AS
          SELECT name FROM fruits WHERE name IN ('apple', 'pear')
        SQL
        original = connection.select_value(
          "SELECT pg_get_viewdef('sweet_fruits'::regclass)"
        ).strip

        allow(connection).to receive(:execute).and_wrap_original do |execute, sql, *args|
          if sql.include?("CREATE TEMPORARY VIEW scenic_stable_definition")
            raise ActiveRecord::StatementInvalid, "cannot recreate view"
          end

          execute.call(sql, *args)
        end

        views = Postgres::Views.new(connection).all

        expect(views.size).to eq 1
        expect(views.first.definition).to eq original
      end
    end
  end
end
