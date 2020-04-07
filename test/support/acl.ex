defmodule GimTest.Acl do
  @moduledoc false
  alias GimTest.Acl.{Access, Permission, Resource, Role, User, Repo}

  @acls %{
    "open" => %Permission{name: "Can open"},
    "update" => %Permission{name: "Can update"},
    "close" => %Permission{name: "Can close"},
    "view" => %Permission{name: "Can view"},
    "delete" => %Permission{name: "Can delete"},
    "admin" => %Role{name: "Admin", permissions: ["open", "update", "close", "view", "delete"]},
    "support" => %Role{name: "Support", permissions: ["open", "update", "close", "view"]},
    "partner" => %Role{name: "Partner", permissions: ["open", "update", "view"]},
    "helpdesk" => %Role{name: "Helpdesk", permissions: ["view"]},
    "intern" => %Resource{name: "Intern"},
    "extern" => %Resource{name: "Extern"},
    "fachgruppe" => %Resource{name: "Fachgruppe"},
    "fachgruppe2" => %Resource{name: "Fachgruppe2"},
    "handel.a" => %Resource{name: "Handel A"},
    "handel.b" => %Resource{name: "Handel B"},
    "the.admin" => %User{name: "The Admin"},
    "the.support" => %User{name: "The Support"},
    "the.helpdesk" => %User{name: "The Helpdesk"},
    "partner.1" => %User{name: "Partner 1"},
    "partner.2" => %User{name: "Partner 2"},
    "partner.3" => %User{name: "Partner 3"},
    "a1.the.admin" => %Access{
      name: "Access 1",
      user: "the.admin",
      resource: "intern",
      role: "admin"
    },
    "a2.the.admin" => %Access{
      name: "Access 2",
      user: "the.admin",
      resource: "extern",
      role: "helpdesk"
    },
    "a1.the.support" => %Access{
      name: "Access 1",
      user: "the.support",
      resource: "intern",
      role: "support"
    },
    "a1.the.helpdesk" => %Access{
      name: "Access 1",
      user: "the.helpdesk",
      resource: "intern",
      role: "helpdesk"
    },
    "a1.partner.1" => %Access{
      name: "Access 1",
      user: "partner.1",
      resource: "fachgruppe",
      role: "support"
    },
    "a2.partner.1" => %Access{
      name: "Access 1",
      user: "partner.1",
      resource: "handel.a",
      role: "partner"
    },
    "a1.partner.2" => %Access{
      name: "Access 1",
      user: "partner.2",
      resource: "fachgruppe",
      role: "support"
    },
    "a2.partner.2" => %Access{
      name: "Access 1",
      user: "partner.2",
      resource: "handel.b",
      role: "partner"
    },
    "a1.partner.3" => %Access{
      name: "Access 1",
      user: "partner.3",
      resource: "handel.b",
      role: "partner"
    }
  }

  def setup do
    Repo.start_link()

    Repo.import(@acls)

    :ok
  end
end
