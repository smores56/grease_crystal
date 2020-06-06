# grease

[![Build Status](https://travis-ci.com/smores56/grease_crystal.svg?branch=master)](https://travis-ci.com/smores56/grease_crystal)

The backend for the Georgia Tech Glee Club's [internal website][glubhub]. You can
find the frontend (written in React + TypeScript) [here][frontend].

This GraphQL API is written in [Crystal][crystal].

_Note: If you are curious about the history of this project or why Crystal was the_ _language used, please read the [corresponding doc][why crystal]_.


## Usage

This API runs using the [CGI][cgi] interface, and exposes a few endpoints:

Endpoint           | Purpose
-------------------|--------
_/graphql_         | The GraphQL API itself
_/graphiql_        | The GraphiQL page, for exploring the API
_/upload_frontend_ | Upload archived build of the [frontend][frontend].

You will access the live version of the GraphiQL instance running at
https://gleeclub.gatech.edu/cgi-bin/grease/graphiql.

<!-- TODO: move to present tense on deployment -->


## Installation

Before you can build, deploy, or contribute to this project, you will need to
[install crystal][install crystal] first.

For testing, you will also want to make sure to install [MySQL][install mysql] and
[Python 3][install python 3].

More information will be provided on how to test this service once development of
features finishes first.


## Deployment

To deploy, you will need access to an account that hold the role of Webmaster on
the internal website. Login to that account to get an API token.

Then all you have to do is set the environment variable `GREASE_TOKEN` to your
API token, and then run `sh build_and_upload.sh`.

_Note: You can retrieve your token on the internal site from the_
_[webmaster tools][webmaster tools] admin tab if you are already logged in, or_
_the `login` mutation on the GraphQL API if you are not._


<!-- ## Development -->
<!-- TODO: this section -->


## Contributing

1. Create your feature branch (`git checkout -b my-new-feature`)
2. Commit your changes (`git commit -am 'Add some feature'`)
3. Push to the branch (`git push origin my-new-feature`)
4. Create a new Pull Request


## Contributors

- [Sam Mohr](https://github.com/smores56) - creator and maintainer


[why crystal]: ./why_crystal.md
[install python 3]: https://www.python.org/downloads/
[install mysql]: https://dev.mysql.com/doc/mysql-installation-excerpt/5.7/en/
[install crystal]: https://crystal-lang.org/install/
[cpp]: https://en.wikipedia.org/wiki/C%2B%2B
[rust]: https://www.rust-lang.org/
[golang]: https://golang.org/
[glubhub]: https://gleeclub.gatech.edu/glubhub/
[grease rust]: https://github.com/GleeClub/grease_api
[frontend]: https://github.com/GleeClub/glubhub_react
[crystal]: https://crystal-lang.org/
[php]: https://www.php.net/
[php sucks]: https://whydoesitsuck.com/why-does-php-suck/
[cgi]: https://en.wikipedia.org/wiki/Common_Gateway_Interface
[webmaster tools]: https://gleeclub.gatech.edu/glubhub/#/admin/webmaster-tools
