# ADR 0010 — Each library owns its own games

Status: Accepted

Date: 2026-10-26

## Context

The OS card is also a place for games. A second SD card and a USB disk can hold games too. An earlier design pooled every card's `Roms` directory into one merged tree. That pool hid which card owned a file, and a write could land on a card the person did not choose.

## Decision

`/storage` is the OS card. It holds settings under `/storage/.config`, and it is the primary library.

A second SD card and a USB disk are additional libraries only while they are mounted. The list is `/run/zlyme/libraries`. A directory left behind after the card is removed is not a library.

A game's ROM, saves, and artwork stay on the library that holds that ROM. A save that already exists is found on any mounted library. When two copies exist, the copy on the game's card is the one used. A new save is created on the game's card. BIOS files are visible together, and a duplicate path uses the copy on the game's card.

A missing card does not move that card's games or saves onto another card.

PortMaster is installed on one chosen library. An empty choice is `/storage`. Another choice counts only when that path is both listed and currently mounted. There is no merged ports directory and no write to an ambiguous card.

## Consequences

`docs/ARCHITECTURE.md` owns the paths and the mount rules.

A merged ROM pool is not reintroduced. A tool that writes a game file names the library first.

## Alternatives

One merged `Roms` tree was rejected. It made ownership and ejection unclear.

Copying a missing card's saves onto `/storage` automatically was rejected. The save would leave the card that owned the game without an explicit choice.
