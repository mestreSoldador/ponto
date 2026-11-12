import { chromium, type Page } from 'playwright';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';

// Modo teste: faz login e para antes de clicar em "Registrar Ponto"  ->  npm run teste
const MODO_TESTE = process.argv.includes('--teste');

// Carrega o .env da pasta do projeto (funciona mesmo quando rodado pelo Agendador de Tarefas)
try {
  process.loadEnvFile(join(__dirname, '.env'));
} catch {
  console.warn('Arquivo .env não encontrado; usando apenas variáveis de ambiente do sistema.');
}

const PASTA_LOGS = join(__dirname, 'logs');
mkdirSync(PASTA_LOGS, { recursive: true });

function agora(): string {
  return new Date().toLocaleString('pt-BR');
}

function log(msg: string) {
  console.log(`[${agora()}] ${msg}`);
}

// Nome de arquivo com data/hora, ex: 2026-11-11_13-04-27
function carimbo(): string {
  const d = new Date();
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`;
}

function obrigatoria(nome: string): string {
  const valor = process.env[nome];
  if (!valor) {
    throw new Error(`Variável ${nome} não definida no .env`);
  }
  return valor;
}

// Localiza o campo pelo placeholder e, se não achar, pelo label
function campo(page: Page, texto: string) {
  return page.getByPlaceholder(texto, { exact: true }).or(page.getByLabel(texto, { exact: true })).first();
}

async function executarAutomacao() {
  log(`Iniciando o robô de automação${MODO_TESTE ? ' (MODO TESTE - não vai registrar o ponto)' : ''}...`);

  const url = obrigatoria('EASYMOB_URL');
  const chaveAcesso = obrigatoria('EASYMOB_CHAVE_ACESSO');
  const usuario = obrigatoria('EASYMOB_USUARIO');
  const senha = obrigatoria('EASYMOB_SENHA');

  // Por padrão roda sem abrir janela. Coloque HEADLESS=false no .env para ver o navegador.
  const headless = process.env.HEADLESS !== 'false';

  const browser = await chromium.launch({ headless });
  const context = await browser.newContext();
  const page = await context.newPage();

  try {
    log(`Acessando ${url}...`);
    await page.goto(url, { waitUntil: 'domcontentloaded' });

    // 1. Login
    const campoChave = campo(page, 'Chave de Acesso');
    await campoChave.waitFor({ state: 'visible', timeout: 30000 });

    log('Preenchendo credenciais...');
    await campoChave.fill(chaveAcesso);
    await campo(page, 'Usuário').fill(usuario);
    await campo(page, 'Senha').fill(senha);

    log('Clicando em ENTRAR...');
    await page.getByRole('button', { name: /^entrar$/i }).click();

    await campo(page, 'Senha').waitFor({ state: 'hidden', timeout: 30000 });
    log('Login realizado com sucesso!');

    // 2. Tela "EasyMOB - Registrar Ponto"
    page.on('dialog', async (dialog) => {
      log(`Diálogo do site: ${dialog.message()}`);
      await dialog.accept();
    });

    const botaoRegistrar = page
      .getByRole('button', { name: 'Registrar Ponto', exact: true })
      .or(page.getByRole('link', { name: 'Registrar Ponto', exact: true }))
      .first();
    await botaoRegistrar.waitFor({ state: 'visible', timeout: 30000 });

    const ultimoRegistro = page.getByText(/Último registro/i).first();
    const antes = (await ultimoRegistro.textContent().catch(() => null))?.trim();
    log(`Antes  -> ${antes ?? '(não encontrado)'}`);

    if (MODO_TESTE) {
      log('Modo teste: botão "Registrar Ponto" encontrado, clique NÃO executado.');
      await page.screenshot({ path: join(PASTA_LOGS, `${carimbo()}_teste.png`), fullPage: true });
      return;
    }

    log('Clicando em Registrar Ponto...');
    await botaoRegistrar.click();

    await page.waitForLoadState('networkidle').catch(() => {});
    await page.waitForTimeout(3000);
    const depois = (await ultimoRegistro.textContent().catch(() => null))?.trim();
    log(`Depois -> ${depois ?? '(não encontrado)'}`);

    const comprovante = join(PASTA_LOGS, `${carimbo()}_comprovante.png`);
    await page.screenshot({ path: comprovante, fullPage: true });

    if (antes && depois && antes === depois) {
      log(`ATENÇÃO: o "Último registro" não mudou. Confira o print ${comprovante}`);
      process.exitCode = 2;
    } else {
      log(`Ponto registrado com sucesso! Comprovante: ${comprovante}`);
    }
  } catch (error) {
    log(`ERRO durante a automação: ${error}`);
    await page.screenshot({ path: join(PASTA_LOGS, `${carimbo()}_erro.png`), fullPage: true }).catch(() => {});
    process.exitCode = 1;
  } finally {
    await browser.close();
  }
}

executarAutomacao();
