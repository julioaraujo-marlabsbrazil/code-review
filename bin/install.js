#!/usr/bin/env node
/*
 * Instala os agents e skills de Code Review (marlabs-code-review) na pasta .github/ do projeto.
 *
 * Copia o pacote para os mesmos caminhos usados pelo POC:
 *   .github/agents/        (agents)
 *   .github/skills/        (skills)
 *   .github/code-review/   (CHANGELOG.md, review-decisions.md e modelo de criterios de aceite)
 *
 * Cuidados:
 *   - Confere o SHA256SUMS do pacote antes de copiar e os arquivos instalados depois de copiar.
 *   - Nunca sobrescreve .github/code-review/review-decisions.md (decisoes do time).
 *   - Se ja houver uma versao instalada, mostra as versoes e pede confirmacao antes de substituir.
 *   - Nao altera nada fora de .github/agents, .github/skills e .github/code-review.
 *   - Nao faz commit: o time revisa e comita a alteracao.
 *
 * Compativel com Node.js 14 ou superior, sem dependencias.
 */
'use strict';

var fs = require('fs');
var path = require('path');
var crypto = require('crypto');
var childProcess = require('child_process');
var readline = require('readline');

var PACKAGE_ROOT = path.resolve(__dirname, '..');
var PLUGIN_DIR = path.join(PACKAGE_ROOT, 'plugins', 'marlabs-code-review');
var SUMS_FILE = path.join(PACKAGE_ROOT, 'SHA256SUMS');
var DECISIONS = '.github/code-review/review-decisions.md';

var USAGE = [
  'Uso: npx marlabs-code-review [opcoes]',
  '',
  'Instala os agents e skills de Code Review na pasta .github/ do projeto (repositorio git).',
  '',
  'Opcoes:',
  '  --target <pasta>  Projeto de destino (padrao: pasta atual)',
  '  --yes, -y         Confirma a substituicao de arquivos existentes sem perguntar',
  '  --dry-run         Mostra o plano sem alterar nada',
  '  --version, -v     Mostra a versao do pacote',
  '  --help, -h        Mostra esta ajuda'
].join('\n');

function fail(message) {
  var error = new Error(message);
  error.expected = true;
  throw error;
}

function parseArgs(argv) {
  var options = { target: '', yes: false, dryRun: false, help: false, version: false };
  for (var i = 0; i < argv.length; i++) {
    var arg = argv[i];
    if (arg === '--target') {
      if (i + 1 >= argv.length) fail('Informe a pasta em --target.');
      options.target = argv[++i];
    } else if (arg.indexOf('--target=') === 0) {
      options.target = arg.slice('--target='.length);
    } else if (arg === '--yes' || arg === '-y') {
      options.yes = true;
    } else if (arg === '--dry-run') {
      options.dryRun = true;
    } else if (arg === '--help' || arg === '-h') {
      options.help = true;
    } else if (arg === '--version' || arg === '-v') {
      options.version = true;
    } else {
      fail('Opcao desconhecida: ' + arg + '\n\n' + USAGE);
    }
  }
  return options;
}

function sha256(file) {
  return crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
}

function packageVersion(corePath) {
  if (!fs.existsSync(corePath)) return null;
  var match = /do pacote: ([^*\r\n]+)\*\*/.exec(fs.readFileSync(corePath, 'utf8'));
  return match ? match[1].trim() : 'desconhecida';
}

function destinationPath(rel) {
  var agent = /^com\.github\.copilot\/agents\/(.+)\.agent\.md$/.exec(rel);
  if (agent) return '.github/agents/' + agent[1] + '.md';
  if (rel.indexOf('skills/') === 0 || rel.indexOf('code-review/') === 0) return '.github/' + rel;
  fail('Arquivo inesperado no SHA256SUMS: ' + rel);
}

function gitRoot(target) {
  try {
    var out = childProcess.execFileSync('git', ['-C', target, 'rev-parse', '--show-toplevel'], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore']
    });
    return path.resolve(out.trim());
  } catch (e) {
    if (e.code === 'ENOENT') fail('git nao encontrado no PATH.');
    fail('O destino nao esta dentro de um repositorio git: ' + target +
      '. Os agents dependem do git para calcular o Change Set.');
  }
}

function readEntries() {
  if (!fs.existsSync(path.join(PLUGIN_DIR, 'plugin.json'))) fail('Pacote nao encontrado em: ' + PLUGIN_DIR);
  if (!fs.existsSync(SUMS_FILE)) fail('SHA256SUMS nao encontrado em: ' + PACKAGE_ROOT);
  var entries = [];
  fs.readFileSync(SUMS_FILE, 'utf8').split(/\r?\n/).forEach(function (line) {
    line = line.trim();
    if (!line) return;
    var match = /^([0-9a-fA-F]{64}) [ *]?(.+)$/.exec(line);
    if (!match) fail('Linha invalida no SHA256SUMS: ' + line);
    var rel = match[2];
    var src = path.join(PLUGIN_DIR, rel);
    var hash = match[1].toLowerCase();
    if (!fs.existsSync(src)) fail('Arquivo do pacote ausente: ' + rel);
    if (sha256(src) !== hash) fail('Hash divergente no pacote: ' + rel + '. O pacote pode estar corrompido.');
    entries.push({ rel: rel, src: src, dst: destinationPath(rel), hash: hash });
  });
  if (entries.length === 0) fail('SHA256SUMS vazio.');
  return entries;
}

function ask(question) {
  return new Promise(function (resolve) {
    var rl = readline.createInterface({ input: process.stdin, output: process.stdout });
    rl.question(question, function (answer) {
      rl.close();
      resolve(answer);
    });
  });
}

function pad(text, size) {
  while (text.length < size) text += ' ';
  return text;
}

function main() {
  var options = parseArgs(process.argv.slice(2));
  var pkg = JSON.parse(fs.readFileSync(path.join(PACKAGE_ROOT, 'package.json'), 'utf8'));
  if (options.help) {
    console.log(USAGE);
    return Promise.resolve(0);
  }
  if (options.version) {
    console.log(pkg.version);
    return Promise.resolve(0);
  }

  // 1. Projeto de destino
  var target = path.resolve(options.target || process.cwd());
  if (!fs.existsSync(target) || !fs.statSync(target).isDirectory()) fail('Pasta de destino nao encontrada: ' + target);
  var root = gitRoot(target);

  // 2. Conferencia do pacote
  var entries = readEntries();
  var newVersion = packageVersion(path.join(PLUGIN_DIR, 'skills', 'code-review-core', 'SKILL.md'));
  var oldVersion = packageVersion(path.join(root, '.github', 'skills', 'code-review-core', 'SKILL.md'));

  // 3. Plano
  var plan = entries.map(function (e) {
    var dstPath = path.join(root, e.dst);
    var action = 'criar';
    if (fs.existsSync(dstPath)) {
      if (e.dst === DECISIONS) action = 'manter';
      else if (sha256(dstPath) === e.hash) action = 'igual';
      else action = 'substituir';
    }
    return { action: action, dst: e.dst, src: e.src, dstPath: dstPath, hash: e.hash };
  });

  console.log('');
  console.log('Projeto:            ' + root);
  console.log('Pacote (npm):       ' + pkg.version);
  console.log('Versao das regras:  ' + newVersion);
  console.log('Versao instalada:   ' + (oldVersion || 'nenhuma'));
  console.log('');
  plan.forEach(function (p) { console.log('  ' + pad(p.action, 11) + ' ' + p.dst); });
  console.log('');

  var toWrite = plan.filter(function (p) { return p.action === 'criar' || p.action === 'substituir'; });
  var toReplace = plan.filter(function (p) { return p.action === 'substituir'; });

  if (toWrite.length === 0) {
    console.log('Nada a fazer: o pacote ja esta instalado nesta versao.');
    return Promise.resolve(0);
  }
  if (options.dryRun) {
    console.log('Simulacao (--dry-run): nenhum arquivo foi alterado.');
    return Promise.resolve(0);
  }

  var confirm = Promise.resolve(true);
  if (toReplace.length > 0 && !options.yes) {
    if (!process.stdin.isTTY) {
      fail(toReplace.length + ' arquivo(s) seriam substituidos. Execute novamente com --yes para confirmar.');
    }
    confirm = ask(toReplace.length + ' arquivo(s) existentes serao substituidos. Continuar? (s/N) ').then(function (answer) {
      return /^(s|sim|y|yes)$/i.test(String(answer).trim());
    });
  }

  return confirm.then(function (ok) {
    if (!ok) {
      console.log('Instalacao cancelada. Nenhum arquivo foi alterado.');
      return 0;
    }

    // 4. Copia
    toWrite.forEach(function (p) {
      fs.mkdirSync(path.dirname(p.dstPath), { recursive: true });
      fs.copyFileSync(p.src, p.dstPath);
    });

    // 5. Conferencia da instalacao
    toWrite.forEach(function (p) {
      if (sha256(p.dstPath) !== p.hash) fail('Hash divergente apos a copia: ' + p.dst);
    });

    console.log('Instalado com sucesso: ' + toWrite.length + ' arquivo(s) gravado(s) e conferido(s).');
    console.log('');
    console.log('Proximos passos (revisar e comitar):');
    console.log('  git status -- .github');
    console.log('  git checkout -b chore/code-review-' + newVersion);
    console.log('  git add .github/agents .github/skills .github/code-review');
    console.log('  git commit -m "chore: instala Code Review ' + newVersion + '"');
    return 0;
  });
}

function report(error) {
  console.error('ERRO: ' + (error && error.expected ? error.message : (error && error.stack) || error));
  process.exitCode = 1;
}

try {
  main().then(function (code) { process.exitCode = code; }, report);
} catch (error) {
  report(error);
}
