#!/bin/bash
# Quick verification script for Ansible optimizations

echo "=== Ansible Optimization Verification ==="
echo ""

echo "1. Checking ansible.cfg configuration..."
ansible-config dump --only-changed | grep -E "(FORKS|PIPELINING|CACHE|CALLBACK|GATHERING)" | sort
echo ""

echo "2. Checking fact cache directory..."
if [ -d /tmp/ansible_facts ]; then
    echo "✅ Fact cache directory exists"
    ls -lh /tmp/ansible_facts/ | head -5
else
    echo "⚠️  Fact cache directory will be created on first run"
fi
echo ""

echo "3. Checking callback plugins..."
if [ -f plugins/callback/custom_timing.py ]; then
    echo "✅ Custom timing callback found"
else
    echo "⚠️  Custom callback not found"
fi
echo ""

echo "4. Checking example playbooks..."
if [ -f playbooks/examples/gpu-async-example.yml ]; then
    echo "✅ Example playbooks found"
    ls -1 playbooks/examples/*.yml
else
    echo "⚠️  Example playbooks not found"
fi
echo ""

echo "5. Running test playbook..."
ansible-playbook playbooks/test-optimizations.yml -v 2>&1 | tail -15
echo ""

echo "=== Verification Complete ==="
