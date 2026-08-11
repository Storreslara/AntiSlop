#!/usr/bin/env node
'use strict';

const { spawn } = require('child_process');
const { hrtime } = require('process');

const MIB = 1024 * 1024;

async function invoke(entryPath, bundleAbsPath, timeoutSeconds, inputs, projectRoot) {
  const startTime = hrtime.bigint();
  let ok = true;
  let exitCode = null;
  let timedOut = false;
  let truncated = false;
  let stdout = '';
  let stderr = '';
  let child = null;
  let timeoutHandle = null;
  let escalateHandle = null;
  let forceResolveHandle = null;
  let resolved = false;

  return new Promise((resolve) => {
    const finish = (result) => {
      if (resolved) return;
      resolved = true;
      clearTimeout(timeoutHandle);
      clearTimeout(escalateHandle);
      clearTimeout(forceResolveHandle);
      resolve(result);
    };

    const buildResult = () => {
      const durationMs = Number((hrtime.bigint() - startTime) / BigInt(1000000));
      return { ok, exitCode, stdout, stderr, durationMs, timedOut, truncated };
    };

    try {
      child = spawn(entryPath, [], {
        cwd: projectRoot,
        env: { ...process.env, MICROWORLD_BUNDLE_DIR: bundleAbsPath },
        shell: false,
        detached: true,
      });

      // Write inputs as JSON to stdin; swallow EPIPE if the entry never reads stdin
      const inputJson = JSON.stringify(inputs);
      child.stdin.on('error', () => {});
      child.stdin.write(inputJson);
      child.stdin.end();

      // Capture stdout
      child.stdout.on('data', (chunk) => {
        const str = chunk.toString();
        if (stdout.length + str.length > MIB) {
          truncated = true;
          const remaining = MIB - stdout.length;
          stdout += str.substring(0, remaining);
        } else {
          stdout += str;
        }
      });

      // Capture stderr
      child.stderr.on('data', (chunk) => {
        const str = chunk.toString();
        if (stderr.length + str.length > MIB) {
          truncated = true;
          const remaining = MIB - stderr.length;
          stderr += str.substring(0, remaining);
        } else {
          stderr += str;
        }
      });

      // Set timeout: kill the whole process group (detached: true made child
      // its own group leader), not just the direct child, so a grandchild
      // holding stdio pipes open can't stall the response. Escalate to
      // SIGKILL if the group survives SIGTERM, then force-resolve regardless
      // of whether 'close' ever fires (e.g. a descendant that detached itself).
      timeoutHandle = setTimeout(() => {
        timedOut = true;
        try {
          process.kill(-child.pid, 'SIGTERM');
        } catch (err) {
          // process group already gone
        }
        escalateHandle = setTimeout(() => {
          try {
            process.kill(-child.pid, 'SIGKILL');
          } catch (err) {
            // process group already gone
          }
          forceResolveHandle = setTimeout(() => finish(buildResult()), 300);
        }, 500);
      }, timeoutSeconds * 1000);

      // Handle child process exit
      child.on('exit', (code) => {
        exitCode = code;
      });

      // Handle child process close (all streams closed)
      child.on('close', () => {
        finish(buildResult());
      });

      // Handle spawn error
      child.on('error', (err) => {
        ok = false;
        stderr = err.message;
        finish(buildResult());
      });
    } catch (err) {
      ok = false;
      stderr = err.message;
      finish(buildResult());
    }
  });
}

module.exports = { invoke };
