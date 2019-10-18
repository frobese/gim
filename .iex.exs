alias GraphDemo.Biblio.{Repo, Author, Book, Publisher}

# Manually insert some Nodes:

# a1 = %Author{name: "William Gibson"} |> Repo.insert()
# a2 = %Author{name: "Terry Pratchett"} |> Repo.insert()
#
# b1 = %Book{title: "Neuromancer"} |> Repo.insert()
# b2 = %Book{title: "Count Zero"} |> Repo.insert()
# b3 = %Book{title: "The Light Fantastic"} |> Repo.insert()
# b4 = %Book{title: "Hogfather"} |> Repo.insert()
#
# p1 = %Publisher{name: "Ace Books"} |> Repo.insert()
# p2 = %Publisher{name: "Victor Gollancz"} |> Repo.insert()
# p3 = %Publisher{name: "Colin Smythe"} |> Repo.insert()

# Manually insert some Edges:

# b1 = b1 |> Book.set_authored_by(a1) |> Book.add_published_by(p1) |> Repo.update()
# b2 = b2 |> Book.set_authored_by(a1) |> Book.add_published_by(p2) |> Repo.update()
# b3 = b3 |> Book.set_authored_by(a2) |> Book.add_published_by(p3) |> Repo.update()
# b4 = b4 |> Book.set_authored_by(a2) |> Book.add_published_by(p2) |> Repo.update()
#
# a1 = a1 |> Author.add_author_of([b1, b2]) |> Repo.update()
# a1 = a2 |> Author.add_author_of([b3, b4]) |> Repo.update()
#
# p1 = p1 |> Publisher.add_publisher_of(b1) |> Repo.update()
# p2 = p2 |> Publisher.add_publisher_of([b2, b4]) |> Repo.update()
# p3 = p3 |> Publisher.add_publisher_of(b3) |> Repo.update()

# -or- Import Nodes

nodes1 = %{
  "a1" => %Author{name: "William Gibson",     author_of: ["b1", "b2"] },
  "a2" => %Author{name: "Terry Pratchett",    author_of: ["b3", "b4"] },
  "b1" => %Book{title: "Neuromancer",         authored_by: "a1", published_by: ["p1"] },
  "b2" => %Book{title: "Count Zero",          authored_by: "a1", published_by: ["p2"] },
  "b3" => %Book{title: "The Light Fantastic", authored_by: "a2", published_by: ["p3"] },
  "b4" => %Book{title: "Hogfather",           authored_by: "a2", published_by: ["p2"] },
  "p1" => %Publisher{name: "Ace Books",       publisher_of: ["b1"] },
  "p2" => %Publisher{name: "Victor Gollancz", publisher_of: ["b2", "b4"] },
  "p3" => %Publisher{name: "Colin Smythe",    publisher_of: ["b3"] },
}

# -or-

nodes2 = %{
  "a1" => %Author{name: "William Gibson",     author_of: ["b1", "b2"] },
  "a2" => %Author{name: "Terry Pratchett",    author_of: ["b3", "b4"] },
  "b1" => %Book{title: "Neuromancer",         },
  "b2" => %Book{title: "Count Zero",          },
  "b3" => %Book{title: "The Light Fantastic", },
  "b4" => %Book{title: "Hogfather",           },
  "p1" => %Publisher{name: "Ace Books",       publisher_of: ["b1"] },
  "p2" => %Publisher{name: "Victor Gollancz", publisher_of: ["b2", "b4"] },
  "p3" => %Publisher{name: "Colin Smythe",    publisher_of: ["b3"] },
}

# -or-

nodes = %{
  "a1" => %Author{name: "William Gibson",     },
  "a2" => %Author{name: "Terry Pratchett",    },
  "b1" => %Book{title: "Neuromancer",         authored_by: "a1", published_by: ["p1"] },
  "b2" => %Book{title: "Count Zero",          authored_by: "a1", published_by: ["p2"] },
  "b3" => %Book{title: "The Light Fantastic", authored_by: "a2", published_by: ["p3"] },
  "b4" => %Book{title: "Hogfather",           authored_by: "a2", published_by: ["p2"] },
  "p1" => %Publisher{name: "Ace Books",       },
  "p2" => %Publisher{name: "Victor Gollancz", },
  "p3" => %Publisher{name: "Colin Smythe",    },
}

# import uses a 2-pass method with create/merge
Repo.import(nodes)

# Repo.all(Author)
# Repo.all(Book)
# Repo.all(Publisher)

# Repo.get(Author, :name, "William Gibson") |> Author.author_of() |> Enum.map(&Book.authored_by/1)
# -or-

import Gim.Query, only: [edge: 2, edges: 2, property: 2]
# Repo.get(Author, :name, "William Gibson") |> edges(:author_of) |> Enum.map(&edge(&1, :published_by))
# Repo.get(Author, :name, "William Gibson") |> edges(:author_of) |> edges(:published_by)
# Repo.get(Author, :name, "William Gibson") |> edges(:author_of) |> edges(:published_by) |> edges(:publisher_of) |> edge(:authored_by)

# Author.__schema__(:properties)
# Author.__schema__(:type, :author_of)
# Author.__schema__(:associations)

#
# -- Untyped example --
#

alias GraphDemo.Untyped
alias GraphDemo.Untyped.{Contact, Hobby, Location}

p1 = %Contact{name: "foo"}
p2 = %Contact{name: "bar"}
h1 = %Hobby{outdoors?: true}
l2 = %Location{area: "The North"}

n1 = %Untyped.Node{id: "one", data: p1} |> Untyped.Repo.insert()
n2 = %Untyped.Node{id: "two", data: p2} |> Untyped.Repo.insert()
n3 = %Untyped.Node{id: "three", data: h1} |> Untyped.Repo.insert()
n4 = %Untyped.Node{id: "four", data: l2} |> Untyped.Repo.insert()

n1 = n1 |> Untyped.Node.add_links(n2) |> Untyped.Repo.update()
n1 = n1 |> Untyped.Node.add_links(n3) |> Untyped.Repo.update()
n2 = n2 |> Untyped.Node.add_links(n4) |> Untyped.Repo.update()

#
# -- Movies Demo --
#

alias GraphDemo.Movies.{Person, Genre, Movie, Character, Performance}
alias GraphDemo.Movies

# "1million.rdf.gz" |> File.stream!([:compressed]) |> Gim.Rdf.read_rdf() |> Movies.Data.map_movies() |> Movies.Repo.import(errors: :ignore)
# -or-  Movies.Data.demo_import()

# Movies.Repo.get(Person, :name, "Sigourney Weaver") |> edges(:actor) |> edges(:film)

# Who played alongside the character Bugs Bunnny?
# Movies.Repo.get(Character, :name, "Bugs Bunny") |> edges(:performances) |> edges(:film) |> edges(:starring) |> edges(:character)

#
# -- Acl Demo
#

alias GraphDemo.Acl.{ Access, Permission, Resource, Role, User }
alias GraphDemo.Acl

acls = %{
  "open" => %Permission{ name: "Can open" },
  "update" => %Permission{ name: "Can update" },
  "close" => %Permission{ name: "Can close" },
  "view" => %Permission{ name: "Can view" },
  "delete" => %Permission{ name: "Can delete" },

  "admin" => %Role{ name: "Admin", permissions: [ "open", "update", "close", "view", "delete" ] },
  "support" => %Role{ name: "Support", permissions: [ "open", "update", "close", "view" ] },
  "partner" => %Role{ name: "Partner", permissions: [ "open", "update", "view" ] },
  "helpdesk" => %Role{ name: "Helpdesk", permissions: [ "view" ] },

  "intern" => %Resource{ name: "Intern" },
  "extern" => %Resource{ name: "Extern" },
  "fachgruppe" => %Resource{ name: "Fachgruppe" },
  "handel.a" => %Resource{ name: "Handel A" },
  "handel.b" => %Resource{ name: "Handel B" },

  "the.admin" => %User{ name: "The Admin" },
  "the.support" => %User{ name: "The Support" },
  "the.helpdesk" => %User{ name: "The Helpdesk" },
  "partner.1" => %User{ name: "Partner 1" },
  "partner.2" => %User{ name: "Partner 2" },
  "partner.3" => %User{ name: "Partner 3" },

  "a1.the.admin"  => %Access{ name: "Access 1", user: "the.admin", resource: "intern", role: "admin" },
  "a2.the.admin"  => %Access{ name: "Access 2", user: "the.admin", resource: "extern", role: "helpdesk" },
  "a1.the.support"  => %Access{ name: "Access 1", user: "the.support", resource: "intern", role: "support" },
  "a1.the.helpdesk"  => %Access{ name: "Access 1", user: "the.helpdesk", resource: "intern", role: "helpdesk" },
  "a1.partner.1"  => %Access{ name: "Access 1", user: "partner.1", resource: "fachgruppe", role: "support" },
  "a2.partner.1"  => %Access{ name: "Access 1", user: "partner.1", resource: "handel.a", role: "partner" },
  "a1.partner.2"  => %Access{ name: "Access 1", user: "partner.2", resource: "fachgruppe", role: "support" },
  "a2.partner.2"  => %Access{ name: "Access 1", user: "partner.2", resource: "handel.b", role: "partner" },
  "a1.partner.3"  => %Access{ name: "Access 1", user: "partner.3", resource: "handel.b", role: "partner" },
}
Acl.Repo.import(acls)

# Gim.Query.repo_to_dotfile(Repo, "biblio.dot", :cluster)
# Gim.Query.repo_to_dotfile(Acl.Repo, "acl.dot", :nocluster)
# $ dot -Tpng -obiblio.png biblio.dot
# $ dot -Tpdf -oacl.pdf acl.dot

admin = Acl.Repo.fetch!(User, :name, "The Admin")
intern = Acl.Repo.fetch!(Resource, :name, "Intern")
extern = Acl.Repo.fetch!(Resource, :name, "Extern")

# Gim.Query.reachable(admin |> edges(:accesses), :resource, intern)
# Gim.Query.reachable(admin |> edges(:accesses), :resource, extern) |> edge(:role) |> property(:name)

# Gim.Query.isolated(Movies.Repo) |> Enum.each(&Movies.Repo.delete/1)
