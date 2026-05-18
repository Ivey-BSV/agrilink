export async function purgeUserData(admin: any, userId: string): Promise<void> {
  const { data: farmRows } = await admin
    .from("farm_details")
    .select("id")
    .eq("user_id", userId);
  const farmIds = (farmRows ?? []).map((r: { id: string }) => r.id);

  if (farmIds.length > 0) {
    await admin.from("farm_network").delete().in("farm_id", farmIds);
    await admin.from("farm_network").delete().in("connected_farm_id", farmIds);
    await admin.from("volunteer_opportunities").delete().in("farm_id", farmIds);
    await admin.from("labor_postings").delete().in("farm_id", farmIds);
    await admin.from("soil_health_logs").delete().in("farm_id", farmIds);
  }

  const { data: postRows } = await admin.from("posts").select("id").eq("user_id", userId);
  const postIds = (postRows ?? []).map((r: { id: string }) => r.id);
  if (postIds.length > 0) {
    await admin.from("comments").delete().in("post_id", postIds);
  }

  await admin.from("post_likes").delete().eq("user_id", userId);
  await admin.from("comments").delete().eq("user_id", userId);
  await admin.from("posts").delete().eq("user_id", userId);

  const { data: listingRows } = await admin
    .from("marketplace_listings")
    .select("id")
    .eq("user_id", userId);
  const listingIds = (listingRows ?? []).map((r: { id: string }) => r.id);
  if (listingIds.length > 0) {
    await admin.from("marketplace_favorites").delete().in("listing_id", listingIds);
  }
  await admin.from("marketplace_favorites").delete().eq("user_id", userId);
  await admin.from("marketplace_listings").delete().eq("user_id", userId);

  const { data: eventRows } = await admin.from("events").select("id").eq("user_id", userId);
  const eventIds = (eventRows ?? []).map((r: { id: string }) => r.id);
  if (eventIds.length > 0) {
    await admin.from("event_registrations").delete().in("event_id", eventIds);
    await admin.from("messages").delete().in("event_id", eventIds);
  }
  await admin.from("event_registrations").delete().eq("user_id", userId);
  await admin.from("events").delete().eq("user_id", userId);

  const { data: chatRows } = await admin
    .from("chats")
    .select("id")
    .or(`user1_id.eq.${userId},user2_id.eq.${userId}`);
  const chatIds = (chatRows ?? []).map((r: { id: string }) => r.id);
  if (chatIds.length > 0) {
    await admin.from("messages").delete().in("chat_id", chatIds);
    await admin.from("chats").delete().in("id", chatIds);
  }

  await admin.from("follows").delete().eq("follower_id", userId);
  await admin.from("follows").delete().eq("following_id", userId);
  await admin.from("user_blocks").delete().eq("blocker_id", userId);
  await admin.from("user_blocks").delete().eq("blocked_id", userId);

  await admin.from("poll_votes").delete().eq("user_id", userId);
  await admin.from("polls").delete().eq("created_by", userId);

  await admin.from("user_notifications").delete().eq("user_id", userId);
  await admin.from("user_notification_settings").delete().eq("user_id", userId);

  const { data: goalRows } = await admin.from("goals").select("id").eq("user_id", userId);
  const goalIds = (goalRows ?? []).map((r: { id: string }) => r.id);
  if (goalIds.length > 0) {
    const { data: milestoneRows } = await admin
      .from("goal_milestones")
      .select("id")
      .in("goal_id", goalIds);
    const milestoneIds = (milestoneRows ?? []).map((r: { id: string }) => r.id);
    if (milestoneIds.length > 0) {
      await admin.from("milestone_completions").delete().in("milestone_id", milestoneIds);
    }
    await admin.from("goal_milestones").delete().in("goal_id", goalIds);
    await admin.from("community_goal_participants").delete().in("goal_id", goalIds);
  }
  await admin.from("community_goal_participants").delete().eq("user_id", userId);
  await admin.from("milestone_completions").delete().eq("user_id", userId);
  await admin.from("goals").delete().eq("user_id", userId);

  const { data: fvRows } = await admin.from("future_visualizations").select("id").eq("user_id", userId);
  const fvIds = (fvRows ?? []).map((r: { id: string }) => r.id);
  if (fvIds.length > 0) {
    await admin.from("future_visualization_milestones").delete().in("future_visualization_id", fvIds);
  }
  await admin.from("future_visualizations").delete().eq("user_id", userId);

  const { data: askRows } = await admin.from("reciprocity_ring_asks").select("id").eq("user_id", userId);
  const askIds = (askRows ?? []).map((r: { id: string }) => r.id);
  if (askIds.length > 0) {
    await admin.from("reciprocity_ring_responses").delete().in("ask_id", askIds);
  }
  await admin.from("reciprocity_ring_responses").delete().eq("user_id", userId);
  await admin.from("reciprocity_ring_asks").delete().eq("user_id", userId);

  const { data: offerRows } = await admin.from("reciprocity_ring_offers").select("id").eq("user_id", userId);
  const offerIds = (offerRows ?? []).map((r: { id: string }) => r.id);
  if (offerIds.length > 0) {
    await admin.from("reciprocity_ring_interests").delete().in("offer_id", offerIds);
  }
  await admin.from("reciprocity_ring_interests").delete().eq("user_id", userId);
  await admin.from("reciprocity_ring_offers").delete().eq("user_id", userId);

  await admin.from("workshop_notes").delete().eq("user_id", userId);
  await admin.from("workshop_documents").delete().eq("user_id", userId);
  await admin.from("goal_documents").delete().eq("user_id", userId);
  await admin.from("knowledge_repository_documents").delete().eq("user_id", userId);
  await admin.from("search_history").delete().eq("user_id", userId);
  await admin.from("labor_postings").delete().eq("user_id", userId);
  await admin.from("soil_health_logs").delete().eq("user_id", userId);
  await admin.from("volunteer_applications").delete().eq("user_id", userId);

  const { data: opportunityRows } = await admin
    .from("volunteer_opportunities")
    .select("id")
    .eq("user_id", userId);
  const opportunityIds = (opportunityRows ?? []).map((r: { id: string }) => r.id);
  if (opportunityIds.length > 0) {
    await admin.from("volunteer_applications").delete().in("opportunity_id", opportunityIds);
  }
  await admin.from("volunteer_opportunities").delete().eq("user_id", userId);

  await admin.from("farm_details").delete().eq("user_id", userId);
  await admin.from("user_profiles").delete().eq("id", userId);
}
