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

  return new Promise((resolve) => {
    try {
      child = spawn(entryPath, [], {
        cwd: projectRoot,
        env: { ...process.env, MICROWORLD_BUNDLE_DIR: bundleAbsPath },
        shell: false,
      });

      // Write inputs as JSON to stdin
      const inputJson = JSON.stringify(inputs);
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

      // Set timeout
      timeoutHandle = setTimeout(() => {
        timedOut = true;
        child.kill('SIGTERM');
      }, timeoutSeconds * 1000);

      // Handle child process exit
      child.on('exit', (code) => {
        if (timeoutHandle) clearTimeout(timeoutHandle);
        exitCode = code;
      });

      // Handle child process close (all streams closed)
      child.on('close', () => {
        const durationMs = Number((hrtime.bigint() - startTime) / BigInt(1000000));
        resolve({
          ok,
          exitCode,
          stdout,
          stderr,
          durationMs,
          timedOut,
          truncated,
        });
      });

      // Handle spawn error
      child.on('error', (err) => {
        ok = false;
        if (timeoutHandle) clearTimeout(timeoutHandle);
        const durationMs = Number((hrtime.bigint() - startTime) / BigInt(1000000));
        resolve({
          ok,
          exitCode: null,
          stdout: '',
          stderr: err.message,
          durationMs,
          timedOut: false,
          truncated: false,
        });
      });
    } catch (err) {
      ok = false;
      if (timeoutHandle) clearTimeout(timeoutHandle);
      const durationMs = Number((hrtime.bigint() - startTime) / BigInt(1000000));
      resolve({
        ok,
        exitCode: null,
        stdout: '',
        stderr: err.message,
        durationMs,
        timedOut: false,
        truncated: false,
      });
    }
  });
}

module.exports = { invoke };
