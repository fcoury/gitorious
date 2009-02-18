# encoding: utf-8
#--
#   Copyright (C) 2007-2009 Johan Sørensen <johan@johansorensen.com>
#   Copyright (C) 2008 David A. Cuadrado <krawek@gmail.com>
#   Copyright (C) 2008 Tim Dysinger <tim@dysinger.net>
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU Affero General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU Affero General Public License for more details.
#
#   You should have received a copy of the GNU Affero General Public License
#   along with this program.  If not, see <http://www.gnu.org/licenses/>.
#++


require File.dirname(__FILE__) + '/../test_helper'

class ProjectTest < ActiveSupport::TestCase


  def create_project(options={})
    Project.new({
      :title => "foo project",
      :slug => "foo",
      :description => "my little project",
      :user => users(:johan),
      :owner => users(:johan)
    }.merge(options))
  end

  should " have a title to be valid" do
    project = create_project(:title => nil)
    assert !project.valid?, 'valid? should be false'
    project.title = "foo"
    assert project.valid?
  end

  should " have a slug to be valid" do
    project = create_project(:slug => nil)
    assert !project.valid?, 'valid? should be false'
  end

  should " have a unique slug to be valid" do
    p1 = create_project
    p1.save!
    p2 = create_project(:slug => "FOO")
    assert !p2.valid?, 'valid? should be false'
    assert_not_nil p2.errors.on(:slug)
  end

  should " have an alphanumeric slug" do
    project = create_project(:slug => "asd asd")
    project.valid?
    assert !project.valid?, 'valid? should be false'
  end

  should " downcase the slug before validation" do
    project = create_project(:slug => "FOO")
    project.valid?
    assert_equal "foo", project.slug
  end
  
  should "cannot have a reserved name as slug" do
    project = create_project(:slug => Gitorious::Reservations.project_names.first)
    project.valid?
    assert_not_nil project.errors.on(:slug)
    
    project = create_project(:slug => "dashboard")
    project.valid?
    assert_not_nil project.errors.on(:slug)
  end
  
  should "creates the wiki repository on create" do
    project = create_project(:slug => "my-new-project")
    project.save!
    assert_instance_of Repository, project.wiki_repository
    assert_equal "my-new-project#{Repository::WIKI_NAME_SUFFIX}", project.wiki_repository.name
    assert_equal Repository::KIND_WIKI, project.wiki_repository.kind
    assert !project.repositories.include?(project.wiki_repository)
    assert_equal project.owner, project.wiki_repository.owner
  end

  should "finds a project by slug or raises" do
    assert_equal projects(:johans), Project.find_by_slug!(projects(:johans).slug)
    assert_raises(ActiveRecord::RecordNotFound) do
      Project.find_by_slug!("asdasdasd")
    end
  end

  should "has the slug as its params" do
    assert_equal projects(:johans).slug, projects(:johans).to_param
  end

  should "knows if a user is a admin on a project" do
    project = projects(:johans)
    assert project.admin?(users(:johan)), 'project.admin?(users(:johan)) should be true'
    project.owner = groups(:team_thunderbird)
    assert !project.admin?(users(:johan)), 'project.admin?(users(:johan)) should be false'
    project.owner.add_member(users(:johan), Role.admin)
    assert project.admin?(users(:johan)), 'project.admin?(users(:johan)) should be true'
    
    assert !project.admin?(users(:moe)), 'project.admin?(users(:moe)) should be false'
    project.owner.add_member(users(:moe), Role.committer)
    assert !project.admin?(users(:moe)), 'project.admin?(users(:moe)) should be false'
    # be able to deal with AuthenticatedSystem's quirky design:
    assert !project.admin?(:false), 'project.admin?(:false) should be false'
    assert !project.admin?(false), 'project.admin?(false) should be false'
    assert !project.admin?(nil), 'project.admin?(nil) should be false'
  end

  should "knows if a user can delete the project" do
    project = projects(:johans)
    assert !project.can_be_deleted_by?(users(:moe)), 'project.can_be_deleted_by?(users(:moe)) should be false'
    assert !project.can_be_deleted_by?(users(:johan)), 'project.can_be_deleted_by?(users(:johan)) should be false'
    (Repository.all_by_owner(project)-project.repositories).each(&:destroy)
    assert project.reload.can_be_deleted_by?(users(:johan)), 'project.reload.can_be_deleted_by?(users(:johan)) should be true'
  end

  should " strip html tags" do
    project = create_project(:description => "<h1>Project A</h1>\n<b>Project A</b> is a....")
    assert_equal "Project A\nProject A is a....", project.stripped_description
  end
  
  should " have a breadcrumb_parent method which returns nil" do
    project = create_project
    assert project.breadcrumb_parent.nil?
  end

  # should "strip html tags, except highlights" do
  #   project = create_project(:description => %Q{<h1>Project A</h1>\n<strong class="highlight">Project A</strong> is a....})
  #   assert_equal %Q(Project A\n<strong class="highlight">Project A</strong> is a....), #   project.stripped_description
  # end

  should "have valid urls ( prepending http:// if needed )" do
    project = projects(:johans)
    [ :home_url, :mailinglist_url, :bugtracker_url ].each do |attr|
      assert project.valid?
      project.send("#{attr}=", 'http://blah.com')
      assert project.valid?
      project.send("#{attr}=", 'ftp://blah.com')
      assert !project.valid?, 'valid? should be false'
      project.send("#{attr}=", 'blah.com')
      assert project.valid?
      assert_equal 'http://blah.com', project.send(attr)
    end
  end
  
  should " not prepend http:// to empty urls" do
    project = projects(:johans)
    [ :home_url, :mailinglist_url, :bugtracker_url ].each do |attr|
      project.send("#{attr}=", '')
      assert project.send(attr).blank?
      project.send("#{attr}=", nil)
      assert project.send(attr).blank?
    end
  end

  should " find or create an associated wiki repo" do
    project = projects(:johans)
    repo = repositories(:johans)
    repo.kind = Repository::KIND_WIKI
    project.wiki_repository = repo
    project.save!
    assert_equal repo, project.reload.wiki_repository
  end
  
  should " have a wiki repository" do
    project = projects(:johans)
    assert_equal repositories(:johans_wiki), project.wiki_repository
    assert !project.repositories.include?(repositories(:johans_wiki))
  end
  
  should "has to_param_with_prefix" do
    assert_equal projects(:johans).to_param, projects(:johans).to_param_with_prefix
  end
  
  should " change the owner of the wiki repo as well" do
    project = projects(:johans)
    project.change_owner_to(groups(:team_thunderbird))
    assert_equal groups(:team_thunderbird), project.owner
    assert_equal groups(:team_thunderbird), project.wiki_repository.owner
  end
  
  should " allow changing ownership from a user to a group, but not the other way around" do
    p = projects(:johans)
    p.change_owner_to(groups(:team_thunderbird))
    assert_equal groups(:team_thunderbird), p.owner
    p.change_owner_to(users(:johan))
    assert_equal groups(:team_thunderbird), p.owner
  end
  
  context "Project events" do
    setup do
      @project = projects(:johans)
      @user = users(:johan)
      @repository = @project.repositories.first
    end
    
    should " create an event from the action name" do
      assert_not_equal nil, @project.create_event(Action::CREATE_PROJECT, @repository, @user, "", "")
    end
    
    should 'allow optional creation of events' do
      assert @project.new_event_required?(Action::UPDATE_WIKI_PAGE, @repository, @user, 'HomePage')
      event = @project.create_event(Action::UPDATE_WIKI_PAGE, @repository, @user, 'HomePage', Time.now)
      assert !@project.new_event_required?(Action::UPDATE_WIKI_PAGE, @repository, @user, 'HomePage')
      event.update_attributes(:created_at => 2.hours.ago)
      assert @project.new_event_required?(Action::UPDATE_WIKI_PAGE, @repository, @user, 'HomePage')
    end
  
    should " create an event even without a valid id" do
      assert_not_equal nil, @project.create_event(52342, @repository, @user)
    end
    
    should "creates valid attributes on the event" do
      e = @project.create_event(Action::COMMIT, @repository, @user, "somedata", "a body")
      assert e.valid?
      assert !e.new_record?, 'e.new_record? should be false'
      e.reload
      assert_equal Action::COMMIT, e.action
      assert_equal @repository, e.target
      assert_equal @project, e.project
      assert_equal @user, e.user
      assert_equal "somedata", e.data
      assert_equal "a body", e.body
    end
  end

end