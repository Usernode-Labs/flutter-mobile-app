#!/bin/bash

adb shell pm clear com.usernode_labs.usernode
adb shell cmd deviceidle whitelist -com.usernode_labs.usernode