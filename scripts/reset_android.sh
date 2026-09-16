#!/bin/bash

adb shell pm clear com.onhomeroom.app
adb shell cmd deviceidle whitelist -com.onhomeroom.app