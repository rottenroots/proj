// projd - núcleo nativo do proj. Lê/escreve os MESMOS .tsv do shell.
//   projd rows [filtro]        n v d desc cat tags criado | acesso acessos bytes fav
//   projd find <nome> [versao] linhas do index.tsv
//   projd here                 projeto que contém $PWD (o mais profundo)
//   projd st get <chave> | st set <chave> campo:valor... | st touch <chave>
#include <cstdio>
#include <cstdlib>
#include <ctime>
#include <fstream>
#include <string>
#include <unordered_map>
#include <unistd.h>
#include <vector>
using namespace std;
using Row = vector<string>;

static string dir_() {
  const char* d = getenv("PROJ_DIR");
  if (d && *d) return d;
  const char* h = getenv("HOME");
  return string(h ? h : "") + "/.config/proj";
}
static Row split(const string& s) {
  Row r; size_t a = 0;
  for (;;) {
    size_t b = s.find('\t', a);
    if (b == string::npos) { r.push_back(s.substr(a)); break; }
    r.push_back(s.substr(a, b - a)); a = b + 1;
  }
  return r;
}
static string join(const Row& r) {
  string o;
  for (size_t i = 0; i < r.size(); i++) { if (i) o += '\t'; o += r[i]; }
  return o;
}
static vector<string> readlines(const string& p) {
  vector<string> v; ifstream f(p); string l;
  while (getline(f, l)) v.push_back(l);
  return v;
}
static string at(const Row& r, size_t i) { return i < r.size() ? r[i] : ""; }
static string z(const Row& r, size_t i) { string s = at(r, i); return s.empty() ? "0" : s; }

static int cmd_rows(const string& filt) {
  unordered_map<string, string> st;
  for (auto& l : readlines(dir_() + "/estado.tsv")) {
    if (l.empty()) continue;
    Row r = split(l);
    st[r[0]] = z(r, 1) + "\t" + z(r, 2) + "\t" + z(r, 3) + "\t" + z(r, 5);
  }
  string out;
  for (auto& l : readlines(dir_() + "/index.tsv")) {
    if (l.empty()) continue;
    Row r = split(l); r.resize(max(r.size(), (size_t)7));
    if (!filt.empty() && r[0].find(filt) == string::npos &&
        r[4].find(filt) == string::npos && r[5].find(filt) == string::npos) continue;
    auto it = st.find(r[0] + "-" + r[1]);
    string c = r[6].empty() ? "-" : r[6];
    out += r[0] + "\t" + r[1] + "\t" + r[2] + "\t" + r[3] + "\t" + r[4] + "\t" + r[5] + "\t" + c + "\t" +
           (it == st.end() ? "0\t0\t0\t0" : it->second) + "\n";
  }
  fwrite(out.data(), 1, out.size(), stdout);
  return 0;
}

static int cmd_find(const string& n, const string& v) {
  string out;
  for (auto& l : readlines(dir_() + "/index.tsv")) {
    Row r = split(l);
    if (r[0] == n && (v.empty() || at(r, 1) == v)) out += l + "\n";
  }
  fwrite(out.data(), 1, out.size(), stdout);
  return 0;
}

static int cmd_here() {
  const char* e = getenv("PWD");
  char buf[4096];
  string p = e ? e : (getcwd(buf, sizeof buf) ? buf : "");
  string best; size_t L = 0;
  for (auto& l : readlines(dir_() + "/index.tsv")) {
    Row r = split(l); string d = at(r, 2);
    if (d.empty()) continue;
    if ((p == d || p.rfind(d + "/", 0) == 0) && d.size() > L) { L = d.size(); best = l; }
  }
  if (!best.empty()) printf("%s\n", best.c_str());
  return 0;
}

static bool st_set(const string& k, const vector<string>& sets) {
  string path = dir_() + "/estado.tsv";
  auto apply = [&](Row& r) {
    if (r.size() < 6) r.resize(6);
    for (int i = 1; i < 6; i++) if (r[i].empty()) r[i] = "0";
    for (auto& s : sets) {
      size_t c = s.find(':'); if (c == string::npos) continue;
      size_t idx = strtoul(s.substr(0, c).c_str(), nullptr, 10);
      if (idx < 2) continue;
      string v = s.substr(c + 1); size_t c2 = v.find(':');
      if (c2 != string::npos) v.resize(c2);
      if (idx > r.size()) r.resize(idx);
      r[idx - 1] = v;
    }
  };
  string out; bool found = false;
  for (auto& l : readlines(path)) {
    Row r = split(l);
    if (r[0] == k) { found = true; apply(r); out += join(r) + "\n"; }
    else out += l + "\n";
  }
  if (!found) { Row r = {k, "0", "0", "0", "0", "0"}; apply(r); out += join(r) + "\n"; }
  string tmp = path + ".projd" + to_string(getpid());
  { ofstream f(tmp, ios::binary); if (!f) return false; f << out; if (!f) return false; }
  if (rename(tmp.c_str(), path.c_str()) != 0) { remove(tmp.c_str()); return false; }
  return true;
}

int main(int argc, char** argv) {
  string c = argc > 1 ? argv[1] : "";
  if (c == "rows") return cmd_rows(argc > 2 ? argv[2] : "");
  if (c == "find" && argc > 2) return cmd_find(argv[2], argc > 3 ? argv[3] : "");
  if (c == "here") return cmd_here();
  if (c == "st" && argc > 3) {
    string op = argv[2], k = argv[3];
    if (op == "get") {
      for (auto& l : readlines(dir_() + "/estado.tsv"))
        if (split(l)[0] == k) printf("%s\n", l.c_str());
      return 0;
    }
    if (op == "set") {
      vector<string> s(argv + 4, argv + argc);
      return st_set(k, s) ? 0 : 1;
    }
    if (op == "touch") {
      long long n = 0;
      for (auto& l : readlines(dir_() + "/estado.tsv")) {
        Row r = split(l);
        if (r[0] == k) { n = strtoll(z(r, 2).c_str(), nullptr, 10); break; }
      }
      return st_set(k, {"2:" + to_string((long long)time(nullptr)), "3:" + to_string(n + 1)}) ? 0 : 1;
    }
  }
  fprintf(stderr, "uso: projd rows|find|here|st get|set|touch\n");
  return 2;
}
