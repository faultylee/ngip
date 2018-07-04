# ngip

[![standard-readme compliant](https://img.shields.io/badge/readme%20style-standard-brightgreen.svg?style=flat-square)](https://github.com/RichardLitt/standard-readme)

> Standard Readme Style

This is an hosted application which works like uptime monitoring tools, but the ping direction is in reverse. The main purpose is to detect uptime of intranet application which doesn't expose any end point to the internet, but are able to send short packets to `ngip.io`. 

## Table of Contents

- [Background](#background)
- [Install](#install)
- [Usage](#usage)
- [Maintainers](#maintainers)
- [Contribute](#contribute)
- [License](#license)

## Background

I came about having this idea when developing an in-house application. It's a somewhat critical application which needs to run 24x7. There's internal monitoring tools from a different team which I could make use of, but going through the process and also segregating the dashboard and notification proof too much hassle. Plus when our internet connectivity is down, i.e. when there's a blackout over the weekend, notification will not arrive.

This application will expect pings from the any application that can access `ngip.io`, and after the ping lapse for a pre-defined duration, a notification is send. The pings can also include primitive data such as temperature, status code ...etc which will be included in the simple validation logic to also send notification when the value is out of bound.

As for the name, initially it was *Reverse Ping* which was long and rather lame. My friend suggested *ngip* which he said sounded like the reverse of ping. I kinda like it and went with it. He gave his blessing on using the name for this project :)


## Install


## Usage


## Maintainers

[@faultylee](https://github.com/faultylee).

## Contribute

Feel free to dive in! [Open an issue](https://github.com/faultylee/ngip/issues/new) or submit PRs.

ngip follows the [Contributor Covenant](http://contributor-covenant.org/version/1/3/0/) Code of Conduct.

## License

[GNU General Public License v3.0](LICENSE) © Mohd Lee

