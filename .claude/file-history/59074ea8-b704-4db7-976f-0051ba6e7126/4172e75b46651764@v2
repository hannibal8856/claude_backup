/*
 * chainprobe.c -- read-only dlmod probe for snmpd.
 *
 * Answers one question with a runtime readout instead of inference: for an OID
 * that in-master registers, does net-snmp keep the other registrations for the
 * same range on subtree->children, and in what order?
 *
 * dump_registry() cannot answer it (it walks ->next only), and the children
 * merge path in agent_registry.c:845-935 has no DEBUGMSG, so there is no way
 * to read this from outside the process.
 *
 * Strictly read-only: it walks the registry and writes a text file. It never
 * registers, unregisters, or mutates anything except its own trigger OID.
 *
 * Trigger:  snmpget .1.3.6.1.4.1.8691.9999.1.0   -> writes /tmp/chain.txt,
 *                                                   returns the chain count.
 */

#include <net-snmp/net-snmp-config.h>
#include <net-snmp/net-snmp-includes.h>
#include <net-snmp/agent/net-snmp-agent-includes.h>
#include <net-snmp/agent/agent_registry.h>
#include <net-snmp/agent/var_struct.h>

#include <dlfcn.h>
#include <stdio.h>

#define OUT_PATH "/tmp/chain.txt"

static oid probe_trigger_oid[] = { 1, 3, 6, 1, 4, 1, 8691, 9999, 1 };

/* Resolved at run time rather than linked: this file must not add a build-time
 * dependency on the agentx mibgroup, and resolving it here also proves the
 * symbol is reachable in snmpd's address space. */
static void *g_agentx_master_handler;

/* OIDs worth asking about by name. Each one is a distinct case:
 * who registers it, at what width, and with what priority. */
struct probe_oid
{
    const char *what;
    oid         o[24];
    int         len;
};

static const struct probe_oid g_probes[] = {
    { "sysMoxaDescr .0 -- in-master scalar vs framework register_instance"
      " (the namelen question)",
      { 1,3,6,1,4,1,8691,602,1,1,1,1,0 }, 13 },
    { "trustedIp col -- dual-registered by design (in-master + framework IterTable)",
      { 1,3,6,1,4,1,8691,602,1,4,1,2,1,1 }, 14 },
    { "mxTurboRingV2 -- framework Subtree, in-master INIT_ENTRY commented out",
      { 1,3,6,1,4,1,8691,603,3,4,1,1 }, 12 },
    { "mxqosdb RW col -- +getfwd +nodelegate, the only listed prefix using derivation",
      { 1,3,6,1,4,1,8691,603,2,9,1,5,1,2 }, 14 },
    { "mxqosdb table-entry level (.603.2.9.1) -- the derivation floor candidate",
      { 1,3,6,1,4,1,8691,603,2,9,1 }, 11 },
    { "mxqosdb MIB root (.603.2.9) -- what the list comment claims derivation reaches",
      { 1,3,6,1,4,1,8691,603,2,9 }, 10 },
    { "mxstcldb col -- iss_build==1, claimed ISS-served",
      { 1,3,6,1,4,1,8691,603,4,4,1,1,1,2 }, 14 },
    { "mxlldp col -- REMAP group, data lives under Aricent .2076, never AgentX-registered",
      { 1,3,6,1,4,1,8691,603,5,1,1,1 }, 12 },
    { "mxportdb col -- delegated + getfwd, known to forward on the wire (ADR-0030)",
      { 1,3,6,1,4,1,8691,603,1,1,1,1,1,2 }, 14 },
    { "mxrstpdb status col -- delegated RO, the big latency win",
      { 1,3,6,1,4,1,8691,603,3,2,2,1,1,1 }, 14 },
    /* The exact ladder mox_snmp_probe_derive() climbs for a mxlldp entry
     * (.603.5.1.1.1, oid_len 12) under the old `len >= 3` floor. The first
     * level whose head is not mox_snmp_handle_entry is what it forwarded to. */
    { "LADDER 11 .603.5.1.1", { 1,3,6,1,4,1,8691,603,5,1,1 }, 11 },
    { "LADDER 10 .603.5.1",   { 1,3,6,1,4,1,8691,603,5,1 }, 10 },
    { "LADDER  9 .603.5",     { 1,3,6,1,4,1,8691,603,5 }, 9 },
    { "LADDER  8 .603",       { 1,3,6,1,4,1,8691,603 }, 8 },
    { "LADDER  7 .8691",      { 1,3,6,1,4,1,8691 }, 7 },
    { "LADDER  6 .1.3.6.1.4.1", { 1,3,6,1,4,1 }, 6 },
    { "LADDER  3 .1.3.6",     { 1,3,6 }, 3 },
};

static void oid_str(const oid *o, size_t len, char *buf, size_t buflen)
{
    size_t n = 0;
    size_t i;

    if (buf == NULL || buflen == 0) {
        return;
    }
    buf[0] = '\0';
    if (o == NULL) {
        snprintf(buf, buflen, "(null)");
        return;
    }
    for (i = 0; i < len && n + 1 < buflen; i++) {
        int w = snprintf(buf + n, buflen - n, ".%lu", (unsigned long) o[i]);
        if (w <= 0 || (size_t) w >= buflen - n) {
            break;
        }
        n += (size_t) w;
    }
}

/* One line per node in a chain. `depth` 0 is the head -- the registration that
 * actually answers the wire; everything below it lost, and by what rule is
 * exactly what this probe is for. */
static void dump_node(FILE *fp, netsnmp_subtree *s, int depth)
{
    char sbuf[320], ebuf[320], nbuf[320];
    const char *hname = "(no reginfo)";
    const char *hhname = "-";
    void *am = NULL;
    void *myvoid = NULL;
    int is_agentx = 0;

    if (s == NULL) {
        return;
    }
    oid_str(s->start_a, s->start_len, sbuf, sizeof(sbuf));
    oid_str(s->end_a, s->end_len, ebuf, sizeof(ebuf));
    oid_str(s->name_a, s->namelen, nbuf, sizeof(nbuf));

    if (s->reginfo != NULL) {
        hname = (s->reginfo->handlerName != NULL) ? s->reginfo->handlerName
                                                  : "(null)";
        if (s->reginfo->handler != NULL) {
            am = (void *) s->reginfo->handler->access_method;
            myvoid = s->reginfo->handler->myvoid;
            hhname = (s->reginfo->handler->handler_name != NULL)
                         ? s->reginfo->handler->handler_name : "-";
            if (g_agentx_master_handler != NULL &&
                am == g_agentx_master_handler) {
                is_agentx = 1;
            }
        }
    }

    fprintf(fp,
            "  [d=%d] name=%s namelen=%d prio=%d range=(%s .. %s)\n"
            "         agentx=%d handlerName=\"%s\" handler_name=\"%s\""
            " access_method=%p myvoid=%p\n",
            depth, nbuf, (int) s->namelen, (int) s->priority, sbuf, ebuf,
            is_agentx, hname, hhname, am, myvoid);
}

static int dump_chain(FILE *fp, netsnmp_subtree *head)
{
    netsnmp_subtree *c;
    int depth = 0;

    for (c = head; c != NULL && depth < 32; c = c->children, depth++) {
        dump_node(fp, c, depth);
    }
    return depth;
}

static long write_dump(void)
{
    FILE *fp;
    subtree_context_cache *ctx;
    long total_subtrees = 0;
    long chained_subtrees = 0;
    long agentx_children = 0;
    size_t i;

    fp = fopen(OUT_PATH, "w");
    if (fp == NULL) {
        return -1;
    }

    fprintf(fp, "== chainprobe ==\n");
    fprintf(fp, "agentx_master_handler = %p %s\n", g_agentx_master_handler,
            (g_agentx_master_handler == NULL) ? "(UNRESOLVED)" : "");

    /* Section A: every region that has more than one registration. If this
     * section is empty, the whole children-chain design is dead on arrival. */
    fprintf(fp, "\n== A. regions with >1 registration (the children chains) ==\n");
    for (ctx = get_top_context_cache(); ctx != NULL; ctx = ctx->next) {
        netsnmp_subtree *s;

        fprintf(fp, "-- context \"%s\"\n",
                (ctx->context_name != NULL) ? ctx->context_name : "(null)");
        for (s = ctx->first_subtree; s != NULL; s = s->next) {
            total_subtrees++;
            if (s->children == NULL) {
                continue;
            }
            chained_subtrees++;
            fprintf(fp, "\n");
            {
                netsnmp_subtree *c;
                int d = 0;
                for (c = s; c != NULL && d < 32; c = c->children, d++) {
                    dump_node(fp, c, d);
                    if (d > 0 && c->reginfo != NULL &&
                        c->reginfo->handler != NULL &&
                        g_agentx_master_handler != NULL &&
                        (void *) c->reginfo->handler->access_method ==
                            g_agentx_master_handler) {
                        agentx_children++;
                    }
                }
            }
        }
    }

    /* Section B: the named cases. netsnmp_subtree_find() is exactly what the
     * forward path would call, so this is the readout the design depends on. */
    fprintf(fp, "\n== B. per-OID lookups ==\n");
    for (i = 0; i < sizeof(g_probes) / sizeof(g_probes[0]); i++) {
        char qbuf[320];
        netsnmp_subtree *found;
        int depth;

        oid_str(g_probes[i].o, (size_t) g_probes[i].len, qbuf, sizeof(qbuf));
        fprintf(fp, "\n-- %s\n   query=%s\n", g_probes[i].what, qbuf);

        found = netsnmp_subtree_find(g_probes[i].o,
                                     (size_t) g_probes[i].len, NULL, NULL);
        if (found == NULL) {
            fprintf(fp, "   -> subtree_find = NULL (nobody registered this)\n");
            continue;
        }
        depth = dump_chain(fp, found);
        fprintf(fp, "   -> chain length %d\n", depth);
    }

    fprintf(fp,
            "\n== summary ==\n"
            "total_subtrees=%ld chained_subtrees=%ld agentx_children=%ld\n",
            total_subtrees, chained_subtrees, agentx_children);
    fclose(fp);
    return chained_subtrees;
}

static int probe_handler(netsnmp_mib_handler *handler,
                         netsnmp_handler_registration *reginfo,
                         netsnmp_agent_request_info *reqinfo,
                         netsnmp_request_info *requests)
{
    static long value;

    (void) handler;
    (void) reginfo;

    if (reqinfo->mode == MODE_GET) {
        value = write_dump();
        snmp_set_var_typed_value(requests->requestvb, ASN_INTEGER,
                                 (u_char *) &value, sizeof(value));
    }
    return SNMP_ERR_NOERROR;
}

void init_chainprobe(void)
{
    netsnmp_handler_registration *reg;

    g_agentx_master_handler = dlsym(RTLD_DEFAULT, "agentx_master_handler");

    reg = netsnmp_create_handler_registration(
        "chainprobe", probe_handler, probe_trigger_oid,
        sizeof(probe_trigger_oid) / sizeof(probe_trigger_oid[0]),
        HANDLER_CAN_RONLY);
    if (reg == NULL) {
        snmp_log(LOG_ERR, "chainprobe: registration alloc failed\n");
        return;
    }
    if (netsnmp_register_scalar(reg) != MIB_REGISTERED_OK) {
        snmp_log(LOG_ERR, "chainprobe: register_scalar failed\n");
        return;
    }
    snmp_log(LOG_INFO, "chainprobe: ready, agentx_master_handler=%p\n",
             g_agentx_master_handler);
}

void deinit_chainprobe(void)
{
}
