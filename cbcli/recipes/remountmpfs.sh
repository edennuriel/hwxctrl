#!/usr/bin/env bash

#remount tmpfs to ensire NOEXEC is disabled
mount -o remount,exec /tmp
