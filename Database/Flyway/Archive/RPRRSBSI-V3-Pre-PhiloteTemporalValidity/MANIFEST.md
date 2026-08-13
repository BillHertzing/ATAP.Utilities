# RPRRSBSI V3 pre-Philote-temporal-validity archive

Archived by PTV-420 on 2026-08-09. These files are the superseded active V3
multi-migration lineage and its header-only `TimeBlock.csv` input. They are
historical evidence only and must not be included in the active Flyway package.

The move preserved every archived file byte-for-byte. The original path and
post-move SHA-256 values are listed below.

| Original active path | Archived path | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `Database/Flyway/SQL/V00010__Create_RPRRSBSI_V3_Core_Schema.sql` | `SQL/V00010__Create_RPRRSBSI_V3_Core_Schema.sql` | 14476 | `245DD2CBDB2D78D4D8288AFA45D4C7668460EED815FEED04C1B095DB090F296B` |
| `Database/Flyway/SQL/V00020__Load_RPRRSBSI_V3_Philote.sql` | `SQL/V00020__Load_RPRRSBSI_V3_Philote.sql` | 7185 | `009171AF6FE973FC5969DF18B04C1E7D05E7FF419EC19711F6F2AC96A8C4B740` |
| `Database/Flyway/SQL/V00030__Load_RPRRSBSI_V3_TimeBlock.sql` | `SQL/V00030__Load_RPRRSBSI_V3_TimeBlock.sql` | 2338 | `7AC687FF921F4FAD5CBBB44636B6236553216C5B77C087019B4D574F6009647B` |
| `Database/Flyway/SQL/V00040__Load_RPRRSBSI_V3_RuleKind.sql` | `SQL/V00040__Load_RPRRSBSI_V3_RuleKind.sql` | 8358 | `C11B683136FFA176B67D715B612170353CE20BBFFFE226C1233EE202D4A60F9E` |
| `Database/Flyway/SQL/V00050__Load_RPRRSBSI_V3_RulePrimitive.sql` | `SQL/V00050__Load_RPRRSBSI_V3_RulePrimitive.sql` | 13737 | `D85FB36EA0BA9DD6E41292840C88E63774B8DE66B471EFB92F15B2D543652FDA` |
| `Database/Flyway/SQL/V00060__Load_RPRRSBSI_V3_RulePrimitiveInput.sql` | `SQL/V00060__Load_RPRRSBSI_V3_RulePrimitiveInput.sql` | 20332 | `D3DFC06926ABB39781AD3BAA67402984099954AE5EEBCB655C84BF3F16ED7947` |
| `Database/Flyway/SQL/V00070__Load_RPRRSBSI_V3_Rule.sql` | `SQL/V00070__Load_RPRRSBSI_V3_Rule.sql` | 10706 | `088DA0E23800CDCB86E4CF4316718AEAB902DBF0216C14014CEBC008514C8D81` |
| `Database/Flyway/SQL/V00080__Load_RPRRSBSI_V3_RuleSet.sql` | `SQL/V00080__Load_RPRRSBSI_V3_RuleSet.sql` | 5028 | `DE25299E161AF69EB8A23C5FA558FC20B6A6B008CDCD67E1DF0DD2F90B309A46` |
| `Database/Flyway/SQL/V00090__Load_RPRRSBSI_V3_RuleSetRule.sql` | `SQL/V00090__Load_RPRRSBSI_V3_RuleSetRule.sql` | 8300 | `79F1548F31190C0C062ADA1EBDF4F65C6208C52FBA45CD9C70E86E7B8A2A58A3` |
| `Database/Flyway/SQL/V00100__Load_RPRRSBSI_V3_BuildSet.sql` | `SQL/V00100__Load_RPRRSBSI_V3_BuildSet.sql` | 6082 | `9D3E7CF682D84ED290F0421877DD23FC906CEDE2978D24C27227DEFA87118ED4` |
| `Database/Flyway/SQL/V00110__Load_RPRRSBSI_V3_BuildSetRuleSet.sql` | `SQL/V00110__Load_RPRRSBSI_V3_BuildSetRuleSet.sql` | 7520 | `50C9A49ECABF365333E1314A5596A30BADD8B8B3063CD858893C65DC2BBD9134` |
| `Database/Flyway/SQL/V00120__Load_RPRRSBSI_V3_Instantiation.sql` | `SQL/V00120__Load_RPRRSBSI_V3_Instantiation.sql` | 6636 | `42E22F5C6FB2BB050ECBE5226BB661F3BDD28F141DC107AF510A8E6D1E19434C` |
| `Database/Flyway/SQL/V00130__Assert_RPRRSBSI_V3_Initial_Graph.sql` | `SQL/V00130__Assert_RPRRSBSI_V3_Initial_Graph.sql` | 21410 | `2BBD8B729B8F1D11850A73EB166FBD82E67466CA85A852A7B4F8A63E886D0C14` |
| `Database/Flyway/Data/TimeBlock.csv` | `Data/TimeBlock.csv` | 60 | `E013893DFAA9443C45984725098812308B214920C4FCD3F4629BD42CB182C6CD` |

Active lineage after this archive operation:

- `Database/Flyway/SQL/V00010__Create_ATAPUtilities_Initial_Schema_And_Seed.sql`
- `Database/Flyway/Data/PhiloteValidityPeriod.csv` and the ten unchanged
  non-temporal seed CSVs.
