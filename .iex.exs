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
# p1 = %Publisher{link: "Ace Books"} |> Repo.insert()
# p2 = %Publisher{link: "Victor Gollancz"} |> Repo.insert()
# p3 = %Publisher{link: "Colin Smythe"} |> Repo.insert()

# Manually insert some Edges:

# b1 = b1 |> Book.set_author(a1) |> Book.add_publishers(p1) |> Repo.update()
# b2 = b2 |> Book.set_author(a1) |> Book.add_publishers(p2) |> Repo.update()
# b3 = b3 |> Book.set_author(a2) |> Book.add_publishers(p3) |> Repo.update()
# b4 = b4 |> Book.set_author(a2) |> Book.add_publishers(p2) |> Repo.update()
#
# a1 = a1 |> Author.add_books([b1, b2]) |> Repo.update()
# a1 = a2 |> Author.add_books([b3, b4]) |> Repo.update()
#
# p1 = p1 |> Publisher.add_books(b1) |> Repo.update()
# p2 = p2 |> Publisher.add_books([b2, b4]) |> Repo.update()
# p3 = p3 |> Publisher.add_books(b3) |> Repo.update()

# -or- Import Nodes

nodes1 = %{
  "a1" => %Author{name: "William Gibson",     books: ["b1", "b2"] },
  "a2" => %Author{name: "Terry Pratchett",    books: ["b3", "b4"] },
  "b1" => %Book{title: "Neuromancer",         author: "a1", publishers: ["p1"] },
  "b2" => %Book{title: "Count Zero",          author: "a1", publishers: ["p2"] },
  "b3" => %Book{title: "The Light Fantastic", author: "a2", publishers: ["p3"] },
  "b4" => %Book{title: "Hogfather",           author: "a2", publishers: ["p2"] },
  "p1" => %Publisher{name: "Ace Books",       books: ["b1"] },
  "p2" => %Publisher{name: "Victor Gollancz", books: ["b2", "b4"] },
  "p3" => %Publisher{name: "Colin Smythe",    books: ["b3"] },
}

# -or-

nodes2 = %{
  "a1" => %Author{name: "William Gibson",     books: ["b1", "b2"] },
  "a2" => %Author{name: "Terry Pratchett",    books: ["b3", "b4"] },
  "b1" => %Book{title: "Neuromancer",         },
  "b2" => %Book{title: "Count Zero",          },
  "b3" => %Book{title: "The Light Fantastic", },
  "b4" => %Book{title: "Hogfather",           },
  "p1" => %Publisher{name: "Ace Books",       books: ["b1"] },
  "p2" => %Publisher{name: "Victor Gollancz", books: ["b2", "b4"] },
  "p3" => %Publisher{name: "Colin Smythe",    books: ["b3"] },
}

# -or-

nodes = %{
  "a1" => %Author{name: "William Gibson",     },
  "a2" => %Author{name: "Terry Pratchett",    },
  "b1" => %Book{title: "Neuromancer",         author: "a1", publishers: ["p1"] },
  "b2" => %Book{title: "Count Zero",          author: "a1", publishers: ["p2"] },
  "b3" => %Book{title: "The Light Fantastic", author: "a2", publishers: ["p3"] },
  "b4" => %Book{title: "Hogfather",           author: "a2", publishers: ["p2"] },
  "p1" => %Publisher{name: "Ace Books",       },
  "p2" => %Publisher{name: "Victor Gollancz", },
  "p3" => %Publisher{name: "Colin Smythe",    },
}

# import uses a 2-pass method with create/merge
Repo.import(nodes)

# Repo.all(Author)
# Repo.all(Book)
# Repo.all(Publisher)

# Repo.get(Author, :name, "William Gibson") |> Author.books() |> Enum.map(&Book.author/1)
# -or-

import Gim.Query, only: [edge: 2, edges: 2, field: 2]
# Repo.get(Author, :name, "William Gibson") |> edges(:books) |> Enum.map(&edge(&1, :publishers))
# Repo.get(Author, :name, "William Gibson") |> edges(:books) |> edges(:publishers)
# Repo.get(Author, :name, "William Gibson") |> edges(:books) |> edges(:publishers) |> edges(:books) |> edge(:author)

# Author.__schema__(:fields)
# Author.__schema__(:type, :books)
# Author.__schema__(:associations)

#
# -- Movies Demo --
#

alias GraphDemo.Movies.{Person, Genre, Movie}
alias GraphDemo.Movies

# Movies.Data.import("data.csv")|> Enum.into(%{}) |> Movies.Repo.import()
# Movies.Repo.get(Person, :name, "Sigourney Weaver")
# Movies.Repo.get(Movie, :name, "Bugs Bunny") |> edges(:director)
# Movies.Repo.get(Movie, :name, "Bugs Bunny") |> edges(:director) |> edges(:director) |> field(:name)

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
# Gim.Query.reachable(admin |> edges(:accesses), :resource, extern) |> edge(:role) |> field(:name)

# Gim.Query.isolated(Movies.Repo) |> Enum.each(&Movies.Repo.delete/1)
