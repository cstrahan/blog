+++
title = "Taming Email With Fastmail Rules"
date = 2023-06-29
draft = false

[taxonomies]
tags = ["email"]
+++

I've been a happy user of [Fastmail](https://www.fastmail.com) for the past 10 years or so.
Recently, I've revisited how I organize my incoming mail (after switching from folders to [labels](https://www.fastmail.com/blog/fastmail-labels/)) and I would like to share my setup and how I manage my GitHub/development notifications in particular.

<!-- more -->

# Goals

Here are a couple goals I had in mind when setting up my mail rules:

- Periodicals/Events/Receipts/etc: labeled respectively and archived
- Social platforms (YouTube/Twitter/etc): comments labeled respectively and archived
- GitHub notifications: labeled such that I can easily filter by issues/PRs I've created, commented on, have been mentioned in, and also include/exclude emails based on project and owner (I consider projects I maintain to be higher priority)
- Mailing list catch-all: I subscribe to a ton of development mailing lists, and anything I haven't deemed worthy of a dedicated label ought to be labeled "Misc Lists" and archived (*unless* the email is addressed to me specifically, in which case I'd like to see it in my inbox as well)

# Implementation

The bulk of my email rules are declared directly [through the Fastmail UI](https://www.fastmail.help/hc/en-us/articles/1500000278122-Organizing-your-inbox).
As opposed to manually writing sieve code in Fastmail's
[sieve](https://www.fastmail.help/hc/en-us/articles/1500000280481)
editor, this yields a couple benefits:

- I don't have to worry about sieve syntax and the possible syntactical and/or logical errors I could introduce.
- When I specify that an email should be given a particular label, I can count on Fastmail keeping the
  generated sieve code working if I later rename that label.
- I can trivially create new rules from current search query, get a preview of matching emails, and also choose to apply that rule to all existing matches.

## Basic Rules

For an example, here's a screenshot of a rule to filter all [Now I Know](https://nowiknow.com/) emails out of my inbox:

{{ image(src="/img/email-rules/now_i_know_rule.png", alt="A screenshot example of Fastmail's email rule UI.",
         position="center") }}

The rule specifies:

```
If ALL of the following conditions apply:
  - From "nowiknow.com"

Then:
  - Archive
  - Add label "Periodical/Now I Know"
  - Continue to apply other rules
```

Some systems don't make it trivial to discern what *type* of email they are sending to you -- e.g. is this a billing email, or reply to a comment, or something else?
YouTube is an excellent example of this. Here are two rules I use to filter direct replies and sibling comments on YouTube:

```
If ALL of the following conditions apply:
  - From "noreply@youtube.com"
  - Subject "replied to you"

Then:
  - Archive
  - Add label "Social/YouTube"
  - Continue to apply other rules
```

and

```
If ALL of the following conditions apply:
  - From "noreply@youtube.com"
  - Subject "New reply to a comment on"

Then:
  - Archive
  - Add label "Social/YouTube"
  - Continue to apply other rules
```

While the [responsible programmer](https://en.wikipedia.org/wiki/Don%27t_repeat_yourself) in me
would like to express this in one rule (since they're both from noreply@youtube.com),
Fastmail's rule UI limits you to choosing only one logical connective per rule (either ALL or ANY).
While I *could* write the desired logic directly in the sieve script, that would just make for more maintenance.
So in these exceptional cases I just accept that I'll have more than one rule to catch everything.

Using the mail rule UI in this way works well for 99% of my filtering needs.
For some more nuanced filtering logic (like the mailing list catch-all, as described further down), I can tack on a small amount of manually written sieve code.

## GitHub Rules

GitHub makes it fairly easy to categorize emails -- in fact, they have an entire [document on filtering email notifications](https://docs.github.com/en/account-and-profile/managing-subscriptions-and-notifications-on-github/setting-up-notifications/configuring-notifications#filtering-email-notifications).

For a trivial example, here's how I filter pushes to repositories:

```
If ALL of the following conditions apply:
  - From "notifications@github.com"
  - To/Cc/Bcc "push@noreply.github.com"

Then:
  - Archive
  - Add label "Dev/GitHub/Push"
  - Continue to apply other rules
```

I have similar rules configured for each of the possible Cc addresses:

- `assign`
- `author`
- `ci_activity`
- `comment`
- `manual`
- `mention`
- `push`
- `review_requested`
- `security_alert`
- `state_change`
- `subscribed`
- `team_mention`
- `your_activity`

A slightly tricker example is filtering all email for my repos. If we consult the aforementioned docs, we'll see this blurb about the `mailing list` field:

> This field identifies the name of the repository and its owner. The format of this address is always `<repository name>.<repository owner>.github.com`.

Here's an example of the `List-ID` header from an email pertaining to one of my repos:

```
List-ID: cstrahan/tree-sitter-nix <tree-sitter-nix.cstrahan.github.com>
```

Knowing this, I have implemented the following rule to label all GitHub notifications regarding my repos:

```
If ALL of the following conditions apply:
  - From "notifications@github.com"
  - A header called "List-ID" contains ".cstrahan.github.com"

Then:
  - Archive
  - Add label "Dev/GitHub/Owner"
  - Continue to apply other rules
```

I can, as one example, now search for notifications that are regarding pushes to repos I own:

```
in:"Dev/GitHub/Owner" in:"Dev/GitHub/Push"
```

There are also some highly active repositories that I would often like to ignore.
One example is [NixOS/nixpkgs](https://github.com/NixOS/nixpkgs): *maybe* 1% of
the notifications are relevant to me, and so while I don't want to outright disable notifications for this repo,
I *would* often like to ignore them when browsing through pushes/assigns/comments/etc in my mail.

Here's a rule (very similar to the previous) to label these nixpkgs notifications:

```
If ALL of the following conditions apply:
  - From "notifications@github.com"
  - A header called "List-ID" contains "nixpkgs.NixOS.github.com"

Then:
  - Archive
  - Add label "Dev/Nixpkgs"
  - Continue to apply other rules
```

Now I can now exclude these Nixpkgs notifications when searching my email for pushes like so:

```
-in:"Dev/Nixpkgs" +in:"Dev/GitHub/Push"
```

## Mailing List Catch-All

To catch the miscellaneous mailing lists, I want to implement the following logic for each incoming email:

```
If:
  - None of the previously executed rules touched this email, and
  - It looks like a mailing list email (based on List-ID and/or Precedence headers)
Then:
  If it is To/Cc/Bcc me:
    - label it "Misc Lists"
    - also keep it in inbox
  Else:
    - label it "Misc Lists"
    - archive it
```

To implement this in sieve, we can exploit how Fastmail generates sieve code for the user configured rules.

For every user configured rule, it splits the generated sieve into two steps:

1. Matching
2. Action

That is, the generated sieve snippets for each rule first checks if the email matches;
if it does, then it sets a variable (in the example further down: `L16_Dev_Nixpkgs`) for the second step to know that the corresponding action (e.g. label, archive, etc) for this rule should occur.

All of the "matching" snippets are chained together in one contiguous block, followed shortly after by the chain of "action" snippets.

Here's an example of the matching logic for the `Dev/Nixpkgs` labeling rule from earlier:

```
# Rule GH Nixpkgs
# Search: "from:notifications@github.com header:List-Id:nixpkgs.NixOS.github.com"
if 
  allof( not string :is "${stop}" "Y",
    jmapquery text:
  {
     "conditions" : [
        {
           "conditions" : [
              {
                 "from" : "notifications@github.com"
              }
           ],
           "operator" : "OR"
        },
        {
           "header" : [
              "List-Id",
              "nixpkgs.NixOS.github.com"
           ]
        }
     ],
     "operator" : "AND"
  }
.
  )
{
  if mailboxidexists "b73930c4-affa-4877-84f0-06cbd4fa5d8e" {
    set "L16_Dev_Nixpkgs" "Y";
  }
}
```

And here's the corresponding action logic:

```
  if string :is "${L16_Dev_Nixpkgs}" "Y" {
    fileinto
      :copy
      :mailboxid "b73930c4-affa-4877-84f0-06cbd4fa5d8e"
      "INBOX.Dev.Nixpkgs";
    set "hasmailbox" "Y";
  }
```

This files a copy of the email into the target mailbox (i.e. label)
and sets `hasmailbox` to `"Y"` to indicate that this email was explicitly given a home.

Rules can result in setting the following (and maybe more) variables to `"Y"`:

- `hasmailbox`: when "Add label" is set
- `deletetotrash`: when "Delete to trash" is set
- `spam`: when "Send to spam" is set
- `skipinbox`: when "Archive (remove inbox label)" is set 

After the final action snippet, this section follows immediately after:

```
  # Then archive or clear implicit keep if skipping inbox
  if string :is "${skipinbox}" "Y" {
    if not string :is "${hasmailbox}" "Y" {
      fileinto
        :specialuse "\\Archive"
        "INBOX.Archive";
    } else {
      discard;
    }
  } else {
    # Set flags for inbox copy
    if not string :is "${read}" "Y" {
      removeflag "\\Seen";
    }
    if string :is "${flagged}" "Y" {
      addflag "\\Flagged";
    }
    # Do MailFetch filing if applicable, otherwise deliver to inbox
  }
```

The idea is:

- if the rule specifies that the inbox should be skipped (`skipinbox="Y"`):
    - and the email was given a label (`hasmailbox="Y"`): we want to move the email into "Archive".
    - otherwise: discard the email
- otherwise:
    - keep this copy in the inbox and set the seen/flagged flags as needed

Knowing this, we can check the variables these rules set to determine if any previous rules have already handled
the current email.

Here's the sieve snippet I tacked onto the very end:

```
# Ignore anything that a rule has already labeled (or otherwise handled)
if not anyof(
  string :is "${hasmailbox}" "Y",
  string :is "${deletetotrash}" "Y",
  string :is "${spam}" "Y",
  string :is "${skipinbox}" "Y"
) {

  # Catch-all for mailing lists that don't have a custom rule/label
  if anyof(
    header "Precedence" "list",
    header "Precedence" "bulk",
    exists "List-Id"
  ) {
    # Add label
    fileinto
      :copy
      "INBOX.Misc Lists";
    set "hasmailbox" "Y";

    # If not addressed directly to me, move into archive
    if not address :is "to" "charles@cstrahan.com" {
      set "skipinbox" "Y";
    }
  }

  # Note: This if-else block is taken directly from the original Fastmail sieve script.
  #
  # Then archive or clear implicit keep if skipping inbox
  if string :is "${skipinbox}" "Y" {
    if not string :is "${hasmailbox}" "Y" {
      fileinto
          :specialuse "\\Archive"
          "INBOX.Archive";
    } else {
      discard;
    }
  } else {
    # Set flags for inbox copy
    if not string :is "${read}" "Y" {
      removeflag "\\Seen";
    }
    if string :is "${flagged}" "Y" {
      addflag "\\Flagged";
    }
    # Do MailFetch filing if applicable, otherwise deliver to inbox
  }

}
```

Now all mailing lists that aren't handled by any other rules get quarantined into one label.

# Future Directions

While I want to keep the hand written sieve code to a minimum, there are some clever things I could do that might be worthwhile:

- Extract the project name from mailing list sender addresses via regex, and add `List/${projectname}` as a label ([this is an example](https://dovecot.org/list/dovecot/2014-September/097846.html)).
- Extract `owner` and `repo` from the `List-ID` via regex, and add both `Dev/GitHub/Owner/${owner}` and `Dev/GitHub/Repo/${repo}` labels.

Also, while the Fastmail UI is pretty responsive and I generally don't have any issues with it, I can think of some things I could do with/to my email if I had a fast, indexed local copy. To do that, I'm considering using [`mujmap`](https://github.com/elizagamedev/mujmap) to synchronize a local copy, with [`notmuch`](https://notmuchmail.org/) providing global-search and tag-based querying. I would have two-way synchronization of `notmuch` "tags" and my Fastmail "labels" so I could just as effectively manage my email from my phone, any arbitrary browser with access to Fastmail.com, or use a local email client with `notmuch` support.

If I go down that road, some clients I'm considering:
- [`aerc`](https://aerc-mail.org/)
- [`meli`](https://meli.delivery/)
- [`neomutt`](https://neomutt.org/)

# A Small Confession

I actually had most of this logic already implemented (with the exception of the GitHub filtering),
but the way I went about it was a constant source of pain: I had *all* of my rules hand written
in sieve code. I would copy the sieve code into a text editor, modify it, and paste it back into my browser's Fastmail tab.
Yeah, not fun at all.

And then I realized I could do 99% of what I want through Fastmail's rules UI, and only use a small bit of sieve code
where the flexibility actually pays off.

# Conclusion

With my email organized as it is now, it is *much* easier to take action on incoming GitHub notifications (and I get a *lot* -- something like 100,000+ a year).
Now that it's easier to keep tabs on things, I actually *enjoy* peeking at notifications as they come through.

{{ image(src="/img/email-rules/non_nixpkgs_mentions.png", alt="A screenshot of me searching for my being mentioned (outside of Nixpkgs).",
         position="center") }}

Bonus: maintaining my filtering rules is actually *easier* than it was before, despite being more nuanced.

Overall, definitely worth the time invested.
