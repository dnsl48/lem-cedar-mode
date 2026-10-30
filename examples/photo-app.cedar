// Policies for the PhotoApp schema in photo-app.cedarschema.
@id("alice-views-vacation")
permit (
    principal == PhotoApp::User::"alice",
    action == PhotoApp::Action::"viewPhoto",
    resource in PhotoApp::Album::"vacation"
);

@id("owners-manage-photos")
permit (
    principal,
    action in [PhotoApp::Action::"editPhoto", PhotoApp::Action::"deletePhoto"],
    resource is PhotoApp::Photo
)
when { resource.owner == principal };

@id("no-private-photos-off-network")
forbid (
    principal,
    action,
    resource is PhotoApp::Photo
)
when { resource.private && !context.sourceIp.isInRange(ip("10.0.0.0/8")) }
unless { principal in PhotoApp::UserGroup::"admins" };

@id("adults-only")
forbid (
    principal,
    action == PhotoApp::Action::"viewPhoto",
    resource
)
when { resource has rating && resource.rating like "adult*" }
unless { principal.age >= 18 };

@id("share-with-template-principal")
permit (
    principal == ?principal,
    action,
    resource in ?resource
);
