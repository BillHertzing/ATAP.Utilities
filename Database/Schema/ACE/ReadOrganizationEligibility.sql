/* Source component for the selected organization migration; not deployed here.
   Caller owns one SERIALIZABLE transaction and must consume all four result sets.
   No authorization decision, credentials, names-as-keys, enrollment or state defaults.
   Overlapping participant periods deliberately produce multiple header rows: reader denies.
*/
CREATE PROCEDURE [ACE].[ReadOrganizationEligibility]
    @UserId uniqueidentifier,
    @HostId uniqueidentifier,
    @SecurityIdentifier nvarchar(184),
    @EffectiveAtUtc datetime2(7)
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT <> 1 OR XACT_STATE() <> 1
        THROW 62610, N'Organization eligibility reader requires its caller-owned transaction.', 1;
    IF @UserId IS NULL OR @HostId IS NULL OR @SecurityIdentifier IS NULL OR LEN(@SecurityIdentifier) = 0
       OR @EffectiveAtUtc IS NULL
        THROW 62611, N'Explicit account, trusted installation/principal and UTC instant are required.', 1;

    -- 1. Exactly one complete account/person/host validity combination is acceptable.
    SELECT u.[UserId], u.[PhiloteId] AS [AccountPhiloteId], u.[PersonId], h.[HostId],
           up.[ValidFromUtc] AS [UserFromUtc], up.[ValidToUtc] AS [UserToUtc],
           pp.[ValidFromUtc] AS [PersonFromUtc], pp.[ValidToUtc] AS [PersonToUtc],
           hp.[ValidFromUtc] AS [HostFromUtc], hp.[ValidToUtc] AS [HostToUtc]
    FROM [ACE].[User] AS u WITH (HOLDLOCK)
    JOIN [ACE].[Person] AS p WITH (HOLDLOCK) ON p.[PersonId] = u.[PersonId]
    JOIN [ACE].[Host] AS h WITH (HOLDLOCK) ON h.[HostId] = @HostId
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS up WITH (HOLDLOCK)
      ON up.[PhiloteId] = u.[PhiloteId] AND up.[ValidFromUtc] <= @EffectiveAtUtc
     AND (up.[ValidToUtc] IS NULL OR @EffectiveAtUtc < up.[ValidToUtc])
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS pp WITH (HOLDLOCK)
      ON pp.[PhiloteId] = p.[PersonId] AND pp.[ValidFromUtc] <= @EffectiveAtUtc
     AND (pp.[ValidToUtc] IS NULL OR @EffectiveAtUtc < pp.[ValidToUtc])
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS hp WITH (HOLDLOCK)
      ON hp.[PhiloteId] = h.[HostId] AND hp.[ValidFromUtc] <= @EffectiveAtUtc
     AND (hp.[ValidToUtc] IS NULL OR @EffectiveAtUtc < hp.[ValidToUtc])
    WHERE u.[UserId] = @UserId;

    -- 2. Preserve all covering states, including conflicts; never SELECT TOP(1) Active.
    SELECT s.[StatusCode], s.[ValidFromUtc], s.[ValidToUtc]
    FROM [ACE].[UserState] AS s WITH (HOLDLOCK)
    WHERE s.[UserId] = @UserId AND s.[ValidFromUtc] <= @EffectiveAtUtc
      AND (s.[ValidToUtc] IS NULL OR @EffectiveAtUtc < s.[ValidToUtc]);

    -- 3. Include another account's matching principal so cross-account ambiguity denies.
    -- An unrelated SID on another account is not returned. Pending bindings remain explicit.
    SELECT b.[BindingId], b.[UserId], b.[IdentityKindCode], b.[HostId],
           b.[SecurityIdentifier], b.[RequestedAccountName] AS [AccountLabel],
           bp.[ValidFromUtc] AS [BindingFromUtc], bp.[ValidToUtc] AS [BindingToUtc],
           s.[BindingStateId], s.[StatusCode], s.[ValidFromUtc] AS [StateFromUtc],
           s.[ValidToUtc] AS [StateToUtc], s.[ObservationReference], s.[VerifiedByActorId], s.[VerifiedAtUtc]
    FROM [ACE].[UserIdentityBinding] AS b WITH (HOLDLOCK)
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS bp WITH (HOLDLOCK)
      ON bp.[PhiloteId] = b.[BindingId] AND bp.[ValidFromUtc] <= @EffectiveAtUtc
     AND (bp.[ValidToUtc] IS NULL OR @EffectiveAtUtc < bp.[ValidToUtc])
    LEFT JOIN [ACE].[UserIdentityBindingState] AS s WITH (HOLDLOCK)
      ON s.[BindingId] = b.[BindingId] AND s.[PhiloteValidityPeriodId] = bp.[PhiloteValidityPeriodId]
     AND s.[ValidFromUtc] <= @EffectiveAtUtc AND (s.[ValidToUtc] IS NULL OR @EffectiveAtUtc < s.[ValidToUtc])
    WHERE b.[HostId] = @HostId AND (b.[UserId] = @UserId OR
          b.[SecurityIdentifier] = @SecurityIdentifier COLLATE Latin1_General_100_BIN2);

    -- 4. Membership/affiliation union, with no role or project grant implied.
    SELECT p.[PersonId], a.[HostId], o.[OrganizationId], a.[AffiliationKindCode],
           mp.[ValidFromUtc] AS [MembershipFromUtc], mp.[ValidToUtc] AS [MembershipToUtc],
           op.[ValidFromUtc] AS [OrganizationFromUtc], op.[ValidToUtc] AS [OrganizationToUtc],
           ap.[ValidFromUtc] AS [AffiliationFromUtc], ap.[ValidToUtc] AS [AffiliationToUtc]
    FROM [ACE].[User] AS u WITH (HOLDLOCK)
    JOIN [ACE].[Person] AS p WITH (HOLDLOCK) ON p.[PersonId] = u.[PersonId]
    JOIN [ACE].[Membership] AS m WITH (HOLDLOCK) ON m.[PersonId] = p.[PersonId]
    JOIN [ACE].[Organization] AS o WITH (HOLDLOCK) ON o.[OrganizationId] = m.[OrganizationId]
    JOIN [ACE].[HostAffiliation] AS a WITH (HOLDLOCK)
      ON a.[OrganizationId] = o.[OrganizationId] AND a.[HostId] = @HostId
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS mp WITH (HOLDLOCK)
      ON mp.[PhiloteId] = m.[MembershipId] AND mp.[ValidFromUtc] <= @EffectiveAtUtc
     AND (mp.[ValidToUtc] IS NULL OR @EffectiveAtUtc < mp.[ValidToUtc])
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS op WITH (HOLDLOCK)
      ON op.[PhiloteId] = o.[OrganizationId] AND op.[ValidFromUtc] <= @EffectiveAtUtc
     AND (op.[ValidToUtc] IS NULL OR @EffectiveAtUtc < op.[ValidToUtc])
    JOIN [ATAPUtilities].[PhiloteValidityPeriod] AS ap WITH (HOLDLOCK)
      ON ap.[PhiloteId] = a.[HostAffiliationId] AND ap.[ValidFromUtc] <= @EffectiveAtUtc
     AND (ap.[ValidToUtc] IS NULL OR @EffectiveAtUtc < ap.[ValidToUtc])
    WHERE u.[UserId] = @UserId;
END;
