#!/usr/bin/env bash
# Open URLs in Brave's Work profile ("Default" directory; Personal is "Profile 2").
open -na "Brave Browser" --args --profile-directory=Default "$@"
