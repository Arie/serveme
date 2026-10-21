// Commits the working-tree changes under the given paths to a branch through
// GitHub's createCommitOnBranch mutation. A commit made through the API with an
// App token is signed by GitHub, which a `git push` from CI is not.
//
//   node .github/scripts/commit-changes.mjs <message> <path>...
//
// Needs GITHUB_TOKEN, GITHUB_REPOSITORY, BRANCH and EXPECTED_HEAD_OID. The
// mutation refuses when the branch has moved past EXPECTED_HEAD_OID, so a
// newer push is never overwritten.
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

export function commitInput({ repository, branch, expectedHeadOid, message, cwd, paths, env = process.env }) {
  const status = execFileSync(
    "git",
    ["status", "--porcelain=v1", "-z", "--untracked-files=all", "--", ...paths],
    { cwd, env, encoding: "utf8" },
  );
  const entries = status
    .split("\0")
    .filter((entry) => entry !== "")
    .map((entry) => ({ code: entry.slice(0, 2), path: entry.slice(3) }))
    .sort((a, b) => a.path.localeCompare(b.path));

  if (entries.length === 0) {
    return null;
  }

  const additions = [];
  const deletions = [];
  for (const { code, path } of entries) {
    if (code.includes("D")) {
      deletions.push({ path });
    } else {
      additions.push({ path, contents: readFileSync(join(cwd, path)).toString("base64") });
    }
  }

  return {
    branch: { repositoryNameWithOwner: repository, branchName: branch },
    expectedHeadOid,
    message: { headline: message },
    fileChanges: { additions, deletions },
  };
}

const mutation = `
  mutation ($input: CreateCommitOnBranchInput!) {
    createCommitOnBranch(input: $input) { commit { oid url } }
  }
`;

async function main([message, ...paths]) {
  const input = commitInput({
    repository: process.env.GITHUB_REPOSITORY,
    branch: process.env.BRANCH,
    expectedHeadOid: process.env.EXPECTED_HEAD_OID,
    message,
    cwd: process.cwd(),
    paths,
  });
  if (input === null) {
    console.log("Nothing changed; no commit.");
    return;
  }

  const response = await fetch("https://api.github.com/graphql", {
    method: "POST",
    headers: { Authorization: `Bearer ${process.env.GITHUB_TOKEN}`, "Content-Type": "application/json" },
    body: JSON.stringify({ query: mutation, variables: { input } }),
  });
  const body = await response.json();
  if (!response.ok || body.errors) {
    throw new Error(`createCommitOnBranch failed: ${JSON.stringify(body.errors ?? body)}`);
  }
  console.log(`Committed ${body.data.createCommitOnBranch.commit.url}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  await main(process.argv.slice(2));
}
