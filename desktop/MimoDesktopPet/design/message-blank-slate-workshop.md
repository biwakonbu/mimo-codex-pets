# Mimo Message Experience: Blank-Slate Workshop

## Goal

Mimo is a companion first and a Codex activity viewer second. The message
experience must let the user enjoy Mimo while answering three questions without
opening a dashboard:

1. Which named Codex chat is Mimo talking about?
2. What is Codex concretely doing, considering, or waiting for there?
3. Can the user open that exact chat directly?

The design must remain understandable with one to six monitored chats and with
an 80-180 character Japanese report.

## Why The Current Composition Fails

- Several similarly styled cards compete with Mimo instead of feeling spoken by
  her.
- Secondary cards truncate the only useful information and can overlap text.
- Generic phrases such as `進めてるよ` do not explain the work or reasoning.
- An overflow count hides chat names, so six-chat monitoring is not actually
  understandable.
- Card numbering, external-link symbols, and synchronized shuffling read as a
  dashboard rather than a living character interaction.
- The visual system assumes that every chat needs a full message at once. A
  520x520 companion cannot make six full reports readable simultaneously.

The redesign therefore separates two jobs:

- **Identity layer:** keep every monitored chat name visible and selectable.
- **Narration layer:** let Mimo tell one complete, readable report at a time.

## Concept Boards

All boards are 1536x1024 raster explorations generated from the same Mimo
identity reference. They are design references only. Production must continue
to render Mimo from the existing pet atlas.

- [Kataribe Stage](ui-proposals/mimo-message-blank-slate-12-kataribe-stage.png)
- [Firefly Charms](ui-proposals/mimo-message-blank-slate-13-firefly-charms.png)
- [Drawing Notebook](ui-proposals/mimo-message-blank-slate-14-drawing-notebook.png)
- [Walking Atelier](ui-proposals/mimo-message-blank-slate-15-walking-atelier.png)

## Direction 1: Kataribe Stage

One matte paper narration surface stays close to Mimo. A slim rail of named
bookmark charms identifies the other chats.

- **One chat:** only the narration surface and chat name are shown.
- **Three chats:** three named charms remain visible; the narrated chat protrudes
  slightly and shares the report accent.
- **Six chats:** all six names remain readable in one vertical rail. Only one
  report occupies reading space.
- **Long report:** the title stays fixed while the body advances by page. The
  current page is explicit, for example `2 / 2`.
- **Click:** the narration surface opens its chat; every charm opens or selects
  its own chat.
- **Mimo relationship:** the report is anchored within 24pt of Mimo and reacts
  with an atlas-backed nod or wave when narration changes.

Strengths: best reading comfort, clearest six-chat model, modest implementation
cost, and stable placement while Mimo wanders.

Risk: a plain rail can become a tab list. The selected hybrid treatment below
prevents that.

## Direction 2: Firefly Charms

Each chat is a named, softly glowing charm. The narrated charm opens into a
leaf-shaped report near Mimo.

- Independent drift periods and phases keep the group alive without synchronized
  movement.
- The active charm has a restrained halo; no status legend is displayed.
- Color may support tone, but the report itself explains the situation in human
  language.
- Six names can remain visible in two shallow arcs.

Strengths: strongest ambient life and a convincing relationship between Mimo
and the monitored chats.

Risk: six charms plus a 180-character report can crowd a 520pt surface. This is
better as an identity-layer treatment than as the complete layout.

## Direction 3: Drawing Notebook

Mimo writes the latest report into a shared notebook. Named ribbon tabs select
the chat.

- New text grows from Mimo's pen side.
- Older entries rise and fade into the paper rather than becoming floating
  cards.
- One to six chats use one or two rows of named tabs.

Strengths: the clearest visual explanation that Mimo authored the report.

Risk: historical entries turn the companion into a feed, and mixing several
chats in one notebook slows one-glance identification.

## Direction 4: Walking Atelier

Each chat owns a tiny named desk. Mimo walks to one desk and opens its report.

- The visited desk determines the narrated chat.
- Existing directional rows make the transition character-led.
- A desk, nameplate, or open notebook can open the associated Codex chat.

Strengths: most playful and strongest sense that Mimo inhabits the desktop.

Risk: six desks consume the whole surface, reduce report size, and make the
reading location move. It should remain an optional future scene, not the main
message system.

## Selected Direction

Adopted **Kataribe Stage** as the information architecture and applied **Firefly
Charms** to its chat rail.

The resulting experience is:

- one complete report close to Mimo;
- one persistent, readable name per monitored chat;
- a softly living bottom-up charm stream instead of tabs or numbered cards;
- direct navigation from both the report and each charm;
- no overflow count that conceals names;
- no raw state labels or dashboard chrome.

## Information Contract

The visible narration contains:

- the real sanitized chat name, never a generic `このチャット` when a safe user
  prompt can provide a title;
- one concrete work topic;
- one current action, consideration, result, or reason for waiting;
- a useful next step only when Codex evidence supports it;
- an optional relative freshness phrase, expressed naturally rather than as a
  system status.

The identity charm contains only:

- the readable chat name;
- a restrained accent and update glow;
- no raw active/waiting/review label.

## Motion Language

Motion communicates character attention, not list mutation.

### Enter

1. The new charm is born at the bottom of the rail and settles over 650-900ms.
   Existing charms can only be pushed upward; they never trade places in both
   directions. The visible charms fill `29pt` rows separated by `3pt`; no
   transparent placement slot may create a larger apparent gap.
2. Its glow breathes twice, each pulse about 380ms with a short uneven gap.
3. The report appears only if that chat becomes the narrator.

### Change Narrator

1. The old report text settles downward 2pt and fades over 180-220ms.
2. Mimo gets a 180-260ms reaction beat using an existing atlas row.
3. The accent changes over 280-320ms.
4. The new report rises 3pt while fading in over 260-320ms with
   `easeOutCubic`.

The narration surface itself remains spatially stable. It does not fly between
chat positions.

### Update Current Report

- Keep the chat title and container fixed.
- Crossfade complete text pages; never mix old and new partial sentences.
- Typewriter reveal is optional and applies to the report body only.
- Preserve enough dwell time to finish reading before automatic pagination.

### Exit

1. The charm dims over 300-450ms.
2. It drifts upward by 6-10pt and fades over 400-550ms.
3. Remaining charms rebalance independently with 40-70ms offsets; they must not
   move as one rigid block.

### Ambient

- Mimo and the report use different breathing periods.
- Each charm uses a stable per-chat duration and phase.
- Amplitude stays below 3pt so chat names remain easy to click and read.
- Ambient motion pauses while the pointer is over an interactive element.

## BDD Acceptance Criteria

```gherkin
Feature: Mimo reports progress from named Codex chats

  Scenario: A report identifies its chat
    Given a safe chat name is available
    When Mimo displays a report
    Then the complete chat name is visible with the report
    And the UI does not replace it with a generic session label

  Scenario: A report explains concrete progress
    When Mimo displays a report
    Then it explains a concrete task and current action or consideration
    And it does not expose raw status labels, logs, paths, or secrets
    And it does not invent an unsupported result or next step

  Scenario Outline: All monitored chats remain identifiable
    Given <count> chats are monitored
    Then every safe chat name is readable without overlap
    And one chat is visually identifiable as the current narrator
    Examples:
      | count |
      | 1     |
      | 3     |
      | 6     |

  Scenario: A chat can be opened directly
    When the user clicks the narration surface or a named charm
    Then the corresponding Codex chat opens
    And blank space does not open a different chat

  Scenario: A long report advances calmly
    Given a report needs multiple pages
    Then the chat name remains visible on every page
    And the current page and total page count are visible
    And the report frame keeps the height required by the longest page
    And each page remains visible for typing time plus reading dwell

  Scenario: Chat updates flow in one direction
    Given Mimo starts narrating another monitored chat
    Then its new charm appears at the bottom of the rail
    And every displaced older charm moves only upward
    And the previous copy fades upward instead of moving down through the list

  Scenario: Updates are paced
    Given Codex produces frequent activity events
    Then Mimo coalesces them into a report update roughly every 30-60 seconds
    And urgent user action may interrupt without waiting for the normal cadence

  Scenario: Motion remains readable
    Then Mimo, report, and charms do not animate in synchronized lockstep
    And no interactive text moves more than 3pt during ambient motion
    And enter and exit transitions never remove content instantaneously
```

## Implementation Resolution

The scattered-card stack and its stack transition constants are no longer used
by the production SwiftUI surface. The chosen implementation is backed by
`PetKataribeStagePresentation`, `PetKataribeStageLayout`, and BDD-focused tests
for one, three, and six chats. Production E2E verifies six visible names,
report-to-Mimo proximity, direct accessibility targets, walking readability,
and the absence of an overflow counter. The coordinator keeps a separate
bottom-up narration feed so a new charm is inserted below and older charms are
only pushed upward. Multi-page reports use compact `64`-character pages and
reserve only two tight height tiers. Charms expose button semantics, visible
hover feedback, independent breathing, and a two-pulse update glow.
