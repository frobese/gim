#!/usr/bin/env perl

use strict;
use warnings;

sub parse_persons {
    # <10511170691297417216> <name> "Crime of Passion"@en .
    while (<>) {
        if (/# --------/) { return; }
        if (/<(.*?)>\s+<name>\s+"(.*)"(\@en)? \./) { print "\"$1\" => %Person{name: \"$2\"},\n"; }
    }
}

sub parse_genres {
    while (<>) {
        if (/# --------/) { return; }
        if (/<(.*?)>\s+<name>\s+"(.*)"(\@en)? \./) { print "\"$1\" => %Genre{name: \"$2\"},\n"; }
    }
}

sub parse_movies {
    # <4516238064421080311> <director.film> <10511170691297417216> .
    # <10511170691297417216> <genre> <1555632717900314026> .
    # <10511170691297417216> <initial_release_date> "1957-01-01T00:00:00Z" .
    my $id = "";
    my $name = "";
    my $date = "";
    my @director = ();
    my @genre = ();
    while (<>) {
        if (/# --------/) { return; }
        if (/<(.*?)>\s+<name>\s+"(.*)"(\@en)? \./) { $id = $1; $name = $2; }
        if (/<(.*?)>\s+<director.film>\s+<(.*)> \./) { $id = $2; push @director, "\"$1\""; }
        if (/<(.*?)>\s+<genre>\s+<(.*)> \./) { $id = $1; push @genre, "\"$2\""; }
        if (/<(.*?)>\s+<initial_release_date>\s+"(.*)" \./) { $id = $1; $date = $2; }

        if (/^\s*$/) {
            my $d = join ',', @director;
            my $g = join ',', @genre;
            print "\"$id\" => %Movie{name: \"$name\", initial_release_date: \"$date\", genre: [$g], director: [$d]},\n";
            $id = "";
            $name = "";
            $date = "";
            @director = ();
            @genre = ();
        }
    }
}

print "%{\n";

while (<>) {
    # -------- directors --------
    # -------- End directors --------
    # -------- actors --------
    # -------- End actors --------
    # -------- genres --------
    # -------- End genres --------
    # -------- movies --------
    # -------- End movies --------
    # -------- Movies Types --------
    # -------- End of Movies Types --------
    # -------- Genres Types --------
    # -------- End Genres Types --------
    # -------- actors --------
    # -------- End Actors Types --------
    # -------- Directors Types --------
    # -------- End of Directors Types --------
    if (/# -------- directors/) { parse_persons(); }
    if (/# -------- actors/) { parse_persons(); }
    if (/# -------- genres/) { parse_genres(); }
    if (/# -------- movies/) { parse_movies(); }
}

print "} |> Repo.import()\n";
