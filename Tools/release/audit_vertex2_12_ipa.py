#!/usr/bin/env python3
import audit_vertex2_ipa as base

base.EXPECTED["CFBundleShortVersionString"] = "12.0.0"
base.EXPECTED["CFBundleVersion"] = "12"

if __name__ == "__main__":
    base.main()
