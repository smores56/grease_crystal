# Why Crystal

This document describes the history of the Glee Club's API and why I switched it
over from Rust to Crystal.


## Initial Implementation

The Glee Club's internal site was first written in PHP as part of a senior project.
Content was rendered to the user by manually building HTML strings, and all server
interaction was done on an imperative, scripting basis. Ignoring the numerous problems
with PHP as a dynamically-typed, imperative language, the structure of the code was
fragile and almost entirely undocumented, and as such, difficult to understand for
new developers. This meant that new Webmasters simply delegated work to Georgia Tech
Glee Club alumni that had previously worked on the site, rather than attempt to understand how things worked for themselves.

This was many years before the advent and maturation of JavaScript and component-based
web pages, and thus had some serious weaknesses compared to modern design approaches.
An initial attempt was made by [Matthew Schauer][matthew schauer] to write a JSON API
to take the first step in separating the backend from the frontend.

<!-- TODO: expound on this -->

However, it was still written in PHP, and so I spearheaded the re-write into a separate JSON API backend and JS frontend.


## First Rewrite

Previously, this JSON API was written in [Rust][rust], which was chosen for a number
of reasons. Primarily, the constraints on the API were imposed by the free hosting
environment provided by Georgia Tech. Basically, if you don't use [PHP][php] (which
is not a good choice for [multiple reasons][php sucks]), your only choice is to use
something that:

- Runs using the [CGI][cgi] protocol (spawn a program for each HTTP request)
- Has a quick startup time (a requirement for CGI programs)
- Compiles statically (the provided VM is lacking of even `git` or `ssl`)
- Is robust, as failure is hard to debug over SSH
- Runs quickly

When first converting the codebase from PHP, the available options at the time seemed
to be [Rust][rust], [Go][golang], and [C++][cpp]. Given my significant personal
familiarity with Rust, dislike of Go for its inconvenience, and ~~fear of~~ lack of
experience with C++, I moved to use Rust.

Rust did the job very well in all categories but one: learnability.


## Why Switch

As mentioned above as to why the re-write was undertaken, the original implementation
of the site worked (well enough), but was indecipherable due to its structure and
serious lack of documentation. We learned the importance of writing an API that others
could get working on very quickly, and that was not true of Rust: as much as I loved
the language, I had to admit that it has too steep of a learning curve for students
to pick it up.

, it was a bonus to pick an easy-to-learn language (like python or
JS/TS), as most students don't have the time outside of their schedules to learn
a new language when something breaks, let alone


## Questions

This document was by me, [Sam Mohr][sam mohr].



[cpp]: https://en.wikipedia.org/wiki/C%2B%2B
[rust]: https://www.rust-lang.org/
[golang]: https://golang.org/
[grease rust]: https://github.com/GleeClub/grease_api
[frontend]: https://github.com/GleeClub/glubhub_react
[crystal]: https://crystal-lang.org/
[php]: https://www.php.net/
[php sucks]: https://whydoesitsuck.com/why-does-php-suck/
[cgi]: https://en.wikipedia.org/wiki/Common_Gateway_Interface
[matthew schauer]: https://github.com/showermat
[sam mohr]: https://github.com/smores56
