# Claude Desktop na Fedorze przez Flatpak

Społecznościowa receptura dla **x86_64**. Każdy fork może prowadzić własne podpisane źródło Flatpaka na GitHub Pages. Przy instalacji i aktualizacji Flatpak pobiera pakiet Claude Desktop bezpośrednio z serwera Anthropic. Na Pages trafiają launcher, środowisko bazowe aplikacji i metadane potrzebne do instalacji.

## Uruchom własne źródło

1. Kliknij **Fork** i utwórz publiczny fork na swoim koncie. W jego zakładce **Actions** włącz workflow, jeśli GitHub wyświetla przycisk aktywacji.
2. Na Fedorze zainstaluj potrzebne narzędzia i zaloguj się do GitHuba. Do konfiguracji wymagane są uprawnienia administratora forka.

   ```bash
   sudo dnf install gh git gnupg2 flatpak
   gh auth login
   ```

3. Sklonuj **swój** fork. Zastąp `TWOJ_LOGIN` własnym loginem i użyj nazwy wybranej przy forkowaniu.

   ```bash
   gh repo clone TWOJ_LOGIN/claude-flatpak
   cd claude-flatpak
   bash scripts/setup.sh
   ```

   Skrypt przełącza Pages na wdrożenia z GitHub Actions, generuje osobny klucz podpisujący i zapisuje go w sekrecie Actions `FLATPAK_GPG_PRIVATE_KEY`. Wypisuje odcisk klucza publicznego. Przy ponownym uruchomieniu zachowuje istniejący sekret. Klucz prywatny po konfiguracji pozostaje w sekrecie GitHuba. Jeśli potrzebujesz własnej kopii zapasowej, przygotuj dedykowany klucz podpisujący bez hasła i ustaw ten sekret w formacie ASCII armor przed uruchomieniem skryptu.

4. Poczekaj, aż oba zadania **build** i **publish** zakończą się pomyślnie. W podsumowaniu budowy znajdziesz adres `claude.flatpakrepo` i odcisk klucza. Każdy fork ma swój adres oraz klucz.

## Dodaj źródło na Fedorze

Ustaw `REMOTE_URL` na adres z podsumowania swojego workflow. Przy standardowych ustawieniach Pages wygląda on tak:

```bash
REMOTE_URL=https://TWOJ_LOGIN.github.io/claude-flatpak/claude.flatpakrepo
flatpak remote-add --user --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak remote-add --user claude-personal "$REMOTE_URL"
flatpak install --user claude-personal com.anthropic.Claude
flatpak run com.anthropic.Claude
```

Jeżeli masz już aplikację o tym samym identyfikatorze z wcześniejszego bundla, po dodaniu nowego źródła wykonaj `flatpak install --user --reinstall claude-personal com.anthropic.Claude`. Sprawdź źródło poleceniem `flatpak info --user --show-origin com.anthropic.Claude` — powinno pokazać `claude-personal`.

## Aktualizacje

Codziennie o 05:27 UTC workflow sprawdza podpisany indeks APT Anthropic. Nowy pakiet lub zmiana rewizji receptury powoduje przebudowę. Ręczny **Run workflow** wymusza przebudowę. Przed publikacją runner instaluje aplikację z podpisanego repozytorium testowego i sprawdza, czy launcher oraz program są dostępne. Na Fedorze pobierzesz aktualizację zwykłym poleceniem:

```bash
flatpak update --user com.anthropic.Claude
```

GitHub może wyłączyć harmonogram po 60 dniach bez aktywności w publicznym repozytorium. Można go wznowić w zakładce **Actions**. Zmiany samej receptury z projektu nadrzędnego pobieraj przez **Sync fork**.

## Dostęp aplikacji

Manifest przyznaje dostęp do sieci, systemowego magazynu poświadczeń i plików hosta przez `--filesystem=host`, z prawami użytkownika. Aplikacja nadal korzysta ze środowiska Flatpaka. Narzędzia Fedory zainstalowane przez DNF mogą wymagać osobnej integracji. Receptura nie konfiguruje QEMU/KVM dla Cowork. Anthropic oficjalnie wspiera linuksowy Desktop na dystrybucjach opartych na Debianie.

## Źródła

- [Pakiet APT, odcisk klucza i wymagania Claude Desktop](https://code.claude.com/docs/en/desktop-linux)
- [Pierwotna receptura Gordona Messmera](https://github.com/gordonmessmer/com.anthropic.Claude)
- [Repozytoria i klucze Flatpaka](https://docs.flatpak.org/en/latest/hosting-a-repository.html)
